"""Task computations that views and other apps call, not reimplement.

Recurring tasks (#124, M8 design §2) follow the rule the class timetable
does: a series is a rule expanded on read for the client's date range, and
only exceptions are rows. Clients never create instances.
"""

import datetime
from collections.abc import Callable, Iterator
from dataclasses import dataclass

from django.db import transaction
from django.db.models import Q, QuerySet
from rest_framework.exceptions import ValidationError

from .models import RecurrenceFreqChoices, Task, TaskRecurrence


def _days(first: datetime.date, last: datetime.date) -> Iterator[datetime.date]:
    current = first
    while current <= last:
        yield current
        current += datetime.timedelta(days=1)


def _monday(day: datetime.date) -> datetime.date:
    return day - datetime.timedelta(days=day.weekday())


def _daily_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    return (day - rule.starts_on).days % rule.interval == 0


def _weekly_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    # Weeks are counted Monday to Monday from the week of starts_on, so an
    # interval of 2 keeps a Monday/Wednesday rule on the same weeks.
    weekdays = rule.weekdays or [rule.starts_on.weekday()]
    weeks = (_monday(day) - _monday(rule.starts_on)).days // 7
    return day.weekday() in weekdays and weeks % rule.interval == 0


def _monthly_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    # A month without the day (the 31st, Feb 29) is skipped, as RFC 5545 does.
    months = (day.year - rule.starts_on.year) * 12 + day.month - rule.starts_on.month
    return day.day == rule.starts_on.day and months % rule.interval == 0


_MATCHERS: dict[str, Callable[[TaskRecurrence, datetime.date], bool]] = {
    RecurrenceFreqChoices.DAILY: _daily_matches,
    RecurrenceFreqChoices.WEEKLY: _weekly_matches,
    RecurrenceFreqChoices.MONTHLY: _monthly_matches,
}


def _bounds(rule: TaskRecurrence, start: datetime.date, end: datetime.date) -> tuple[datetime.date, datetime.date]:
    """`start`..`end` clipped to the rule's own starts_on..until."""
    last = end if rule.until is None else min(end, rule.until)
    return max(start, rule.starts_on), last


def occurs_on(rule: TaskRecurrence, day: datetime.date) -> bool:
    """Whether `day` is one of the rule's dates: inside starts_on..until and on its pattern.

    >>> occurs_on(rule, datetime.date(2026, 3, 4))
    True
    """
    first, last = _bounds(rule, day, day)
    return first <= last and _MATCHERS[rule.freq](rule, day)


def occurrence_dates(rule: TaskRecurrence, start: datetime.date, end: datetime.date) -> list[datetime.date]:
    """The rule's dates in `start`..`end` (inclusive), in order.

    >>> occurrence_dates(rule, datetime.date(2026, 3, 2), datetime.date(2026, 3, 8))
    [datetime.date(2026, 3, 2), datetime.date(2026, 3, 4)]
    """
    first, last = _bounds(rule, start, end)
    matches = _MATCHERS[rule.freq]
    return [day for day in _days(first, last) if matches(rule, day)]


@dataclass(frozen=True)
class VirtualOccurrence:
    """A series' occurrence on `day` that nothing has written to, so it is not a row.

    The client sees it task-shaped, with `id: null` (M8 design §2).
    """

    template: Task
    day: datetime.date

    @property
    def scheduled_date(self) -> datetime.date:
        return self.day

    @property
    def estimated_minutes(self) -> int | None:
        return self.template.estimated_minutes


DayItem = Task | VirtualOccurrence


def _owned_tasks(user) -> QuerySet[Task]:
    """`user`'s tasks, joined and prefetched for TaskDayListSerializer (invariant 1)."""
    return (
        Task.objects.filter(user=user)
        .select_related("recurrence", "series__recurrence")
        .prefetch_related("tags", "time_blocks", "subtasks")
    )


def _live_templates(user, start: datetime.date, end: datetime.date) -> list[Task]:
    """`user`'s series templates whose rule overlaps `start`..`end`."""
    overlaps = Q(recurrence__until__isnull=True) | Q(recurrence__until__gte=start)
    return list(_owned_tasks(user).filter(recurrence__starts_on__lte=end).filter(overlaps))


def _virtual_occurrences(user, start: datetime.date, end: datetime.date) -> list[VirtualOccurrence]:
    """Each rule date in `start`..`end` that has no stored row, in one query for the rows."""
    stored = set(
        Task.objects.filter(user=user, series__isnull=False, occurrence_date__range=(start, end)).values_list(
            "series_id", "occurrence_date"
        )
    )
    return [
        VirtualOccurrence(template=template, day=day)
        for template in _live_templates(user, start, end)
        for day in occurrence_dates(template.recurrence, start, end)
        if (template.pk, day) not in stored
    ]


def day_items(user, start: datetime.date, end: datetime.date) -> list[DayItem]:
    """`user`'s tasks for `start`..`end` (inclusive): rows scheduled there, plus computed occurrences.

    Rows exclude series templates and skipped occurrences. A rule date with
    no stored (series, date) row is a VirtualOccurrence; a stored row, moved
    or skipped, replaces it. Ordered by date, rows before virtual items on a
    day. Nine queries, however many series (#124).

    >>> day_items(request.user, datetime.date(2026, 3, 2), datetime.date(2026, 3, 2))
    """
    rows = _owned_tasks(user).filter(scheduled_date__range=(start, end), recurrence__isnull=True, is_skipped=False)
    items: list[DayItem] = [*rows, *_virtual_occurrences(user, start, end)]
    # sorted() is stable: rows keep the model ordering within a day.
    return sorted(items, key=lambda item: item.scheduled_date)


# What an occurrence, or a new template, takes from the task it is made from.
# Completion, dates, reminders, subtasks and blocks stay with each row (M8 §2).
_COPIED_FIELDS = (
    "user_id",
    "title",
    "description",
    "notes",
    "priority",
    "area",
    "project_id",
    "discipline_id",
    "estimated_minutes",
    "kanban_order",
)


def _copy_task(source: Task, **fields: object) -> Task:
    copy = Task.objects.create(**{name: getattr(source, name) for name in _COPIED_FIELDS}, **fields)
    copy.tags.set(source.tags.all())
    return copy


def series_template(task: Task) -> Task:
    """The template of the series `task` belongs to or templates; a 400 when it is in none.

    >>> series_template(occurrence) == occurrence.series
    True
    """
    if task.series is not None:
        return task.series
    if hasattr(task, "recurrence"):
        return task
    raise ValidationError(
        {"series": f"task {task.pk} is not in a series; expected a series template or one of its occurrences."}
    )


def materialize_occurrence(template: Task, day: datetime.date) -> tuple[Task, bool]:
    """Get or create the row for (template, day), copied from the template; returns (row, created).

    Idempotent by that natural key, so the outbox replays it (#124). A stored
    row is returned even if the rule has since changed; a new one needs `day`
    to be a rule date, or it is a 400.

    >>> row, created = materialize_occurrence(template, datetime.date(2026, 3, 4))
    """
    with transaction.atomic():
        # Locking the template serializes two first writes to one occurrence.
        template = Task.objects.select_for_update(of=("self",)).select_related("recurrence").get(pk=template.pk)
        existing = Task.objects.filter(series=template, occurrence_date=day).first()
        if existing is not None:
            return existing, False
        rule = template.recurrence
        if not occurs_on(rule, day):
            raise ValidationError(
                {
                    "date": f"{day.isoformat()} is not an occurrence of series {template.pk}: expected a date its "
                    f"{rule.freq} rule produces from {rule.starts_on.isoformat()} to {rule.until or 'no end'}."
                }
            )
        return _copy_task(template, series=template, occurrence_date=day, scheduled_date=day), True


def _template_for_rule(task: Task, starts_on: datetime.date) -> Task:
    """The series template for `task`, splitting a plain task into template plus first occurrence."""
    if task.series is not None:
        return task.series
    if hasattr(task, "recurrence"):
        return task
    template = _copy_task(task)
    # The task stays the first occurrence: its blocks, subtasks and completion stay put (M8 §2).
    task.series, task.occurrence_date = template, task.scheduled_date or starts_on
    task.save(update_fields=["series", "occurrence_date", "updated_at"])
    return template


def set_recurrence(task: Task, rule_values: dict) -> Task:
    """Set the rule of `task`'s series, making one if `task` is in none; returns `task` reloaded.

    >>> set_recurrence(task, {"freq": "daily", "interval": 1, "weekdays": [], "starts_on": day, "until": None})
    """
    with transaction.atomic():
        # Two concurrent PUTs on a plain task must not make two templates.
        locked = Task.objects.select_for_update().get(pk=task.pk)
        template = _template_for_rule(locked, rule_values["starts_on"])
        TaskRecurrence.objects.update_or_create(task=template, defaults=rule_values)
    return _owned_tasks(task.user).get(pk=task.pk)


def stop_recurrence(task: Task, day: datetime.date) -> None:
    """End `task`'s series before the client's `day`; rows already stored are history and stay.

    until becomes day - 1, never later than it was, and never before
    starts_on - 1, which is an empty series.

    >>> stop_recurrence(task, datetime.date(2026, 3, 9))
    """
    rule = series_template(task).recurrence
    last = day - datetime.timedelta(days=1)
    earliest = rule.starts_on - datetime.timedelta(days=1)
    rule.until = max(earliest, min(last, rule.until or last))
    rule.save(update_fields=["until", "updated_at"])

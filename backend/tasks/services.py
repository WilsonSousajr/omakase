"""Task computations that views and other apps call, not reimplement.

Recurring tasks (#124, M8 design §2) follow the rule the class timetable
does: a series is a rule expanded on read for the client's date range, and
only exceptions are rows. Clients never create instances.
"""

import datetime
from collections.abc import Callable, Iterator
from dataclasses import dataclass

from django.db.models import Q, QuerySet

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

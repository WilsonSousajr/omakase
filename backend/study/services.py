"""Study computations that views and other apps call, not reimplement."""

import datetime
import uuid
from collections import defaultdict
from collections.abc import Iterator
from dataclasses import dataclass, field

from rest_framework.exceptions import ValidationError

from .models import ClassCancellation, ClassSchedule, Holiday, Semester


@dataclass(frozen=True)
class _Exceptions:
    """The stored exceptions to the weekly rule over one expansion's range (#125)."""

    holidays: dict[uuid.UUID, list[tuple[datetime.date, datetime.date]]] = field(default_factory=dict)
    cancelled: set[tuple[uuid.UUID, datetime.date]] = field(default_factory=set)

    def in_holiday(self, semester_id: uuid.UUID, day: datetime.date) -> bool:
        return any(first <= day <= last for first, last in self.holidays.get(semester_id, ()))


def _holidays(start: datetime.date, end: datetime.date, **scope) -> dict:
    """Holiday ranges overlapping `start`..`end`, by semester id, in one query."""
    ranges = defaultdict(list)
    rows = Holiday.objects.filter(start_date__lte=end, end_date__gte=start, **scope)
    for semester_id, first, last in rows.values_list("semester_id", "start_date", "end_date"):
        ranges[semester_id].append((first, last))
    return ranges


def _cancellations(start: datetime.date, end: datetime.date, **scope) -> set:
    """(schedule id, date) pairs cancelled in `start`..`end`, in one query."""
    rows = ClassCancellation.objects.filter(date__range=(start, end), **scope)
    return set(rows.values_list("class_schedule_id", "date"))


def _monday(day: datetime.date) -> datetime.date:
    return day - datetime.timedelta(days=day.weekday())


def rotation_week(day: datetime.date, anchor: datetime.date, rotation_weeks: int) -> int:
    """The 1-based rotation week that `day` falls in (#126).

    Weeks run Monday to Sunday, and the anchor's Monday starts week 1, so an
    anchor mid-week still makes its whole week week 1.

    >>> rotation_week(datetime.date(2026, 3, 9), datetime.date(2026, 3, 4), 2)
    2
    """
    weeks_since_anchor = (_monday(day) - _monday(anchor)).days // 7
    return weeks_since_anchor % rotation_weeks + 1


def _semester_week(semester: Semester, day: datetime.date) -> int:
    return rotation_week(day, semester.rotation_anchor or semester.start_date, semester.rotation_weeks)


def _schedule_dates(schedule: ClassSchedule, start: datetime.date, end: datetime.date) -> Iterator[datetime.date]:
    """The dates in `start`..`end` on the schedule's weekday, inside its semester."""
    semester = schedule.discipline.semester
    current = max(start, semester.start_date)
    last = min(end, semester.end_date)
    current += datetime.timedelta(days=(schedule.day_of_week - current.weekday()) % 7)
    while current <= last:
        yield current
        current += datetime.timedelta(days=7)


def _occurrence(schedule: ClassSchedule, day: datetime.date, week: int, is_cancelled: bool) -> dict:
    return {
        "id": f"{schedule.id}-{day.isoformat()}",
        "class_schedule_id": schedule.id,
        "discipline_name": schedule.discipline.name,
        "discipline_color": schedule.discipline.color,
        "class_type": schedule.class_type,
        "location": schedule.location,
        "date": day,
        "start_time": schedule.start_time,
        "end_time": schedule.end_time,
        "week": week,
        "is_cancelled": is_cancelled,
    }


def _schedule_occurrences(
    schedule: ClassSchedule, start: datetime.date, end: datetime.date, exceptions: _Exceptions
) -> list[dict]:
    semester = schedule.discipline.semester
    weeks_on = set(schedule.rotation_weeks_on)
    occurrences = []
    for day in _schedule_dates(schedule, start, end):
        week = _semester_week(semester, day)
        # A holiday omits the class; a cancellation keeps it, marked (M8 design §1).
        if (weeks_on and week not in weeks_on) or exceptions.in_holiday(semester.id, day):
            continue
        occurrences.append(_occurrence(schedule, day, week, (schedule.id, day) in exceptions.cancelled))
    return occurrences


def class_occurrences(user, start: datetime.date, end: datetime.date) -> list[dict]:
    """Expand `user`'s active weekly class schedules into dated occurrences.

    Each occurrence is a dict shaped for `ClassOccurrenceSerializer`, one per
    day in `start`..`end` (inclusive) that matches a schedule's weekday, lies
    inside its semester, falls in one of its rotation weeks (#126) and is not
    in one of the semester's holidays (#125). A cancelled occurrence is kept
    with `is_cancelled` set. Three queries, however many schedules (#176).

    >>> class_occurrences(request.user, datetime.date(2026, 3, 2), datetime.date(2026, 3, 8))
    """
    schedules = ClassSchedule.objects.filter(
        discipline__semester__user=user,
        is_active=True,
    ).select_related("discipline__semester")
    exceptions = _Exceptions(
        holidays=_holidays(start, end, semester__user=user),
        cancelled=_cancellations(start, end, class_schedule__discipline__semester__user=user),
    )

    occurrences = []
    for schedule in schedules:
        occurrences.extend(_schedule_occurrences(schedule, start, end, exceptions))
    return occurrences


def class_occurs_on(schedule: ClassSchedule, day: datetime.date) -> bool:
    """Whether the schedule has a class on `day`: active, weekday, semester, rotation, no holiday.

    >>> class_occurs_on(schedule, datetime.date(2026, 3, 9))
    True
    """
    if not schedule.is_active:
        return False
    exceptions = _Exceptions(holidays=_holidays(day, day, semester=schedule.discipline.semester))
    return bool(_schedule_occurrences(schedule, day, day, exceptions))


def cancel_class(schedule: ClassSchedule, day: datetime.date) -> tuple[ClassCancellation, bool]:
    """Cancel the schedule's class on `day`, idempotently; returns (cancellation, created).

    A date that is not an occurrence is a 400: there is nothing to cancel.

    >>> cancellation, created = cancel_class(schedule, datetime.date(2026, 3, 9))
    """
    if not class_occurs_on(schedule, day):
        raise ValidationError(
            {
                "date": f"{day.isoformat()} is not an occurrence of class schedule {schedule.id}: "
                "expected its weekday, inside its semester, in one of its rotation weeks and outside a holiday."
            }
        )
    return ClassCancellation.objects.get_or_create(class_schedule=schedule, date=day)


def restore_class(schedule: ClassSchedule, day: datetime.date) -> None:
    """Undo a cancellation; restoring a class that was not cancelled is a no-op.

    >>> restore_class(schedule, datetime.date(2026, 3, 9))
    """
    ClassCancellation.objects.filter(class_schedule=schedule, date=day).delete()

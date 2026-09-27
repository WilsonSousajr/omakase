"""Study computations that views and other apps call, not reimplement."""

import datetime
from collections.abc import Iterator

from .models import ClassSchedule, Semester


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


def _occurrence(schedule: ClassSchedule, day: datetime.date, week: int) -> dict:
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
    }


def _schedule_occurrences(schedule: ClassSchedule, start: datetime.date, end: datetime.date) -> list[dict]:
    semester = schedule.discipline.semester
    weeks_on = set(schedule.rotation_weeks_on)
    occurrences = []
    for day in _schedule_dates(schedule, start, end):
        week = _semester_week(semester, day)
        if not weeks_on or week in weeks_on:
            occurrences.append(_occurrence(schedule, day, week))
    return occurrences


def class_occurrences(user, start: datetime.date, end: datetime.date) -> list[dict]:
    """Expand `user`'s active weekly class schedules into dated occurrences.

    Each occurrence is a dict shaped for `ClassOccurrenceSerializer`, one per
    day in `start`..`end` (inclusive) that matches a schedule's weekday, lies
    inside its semester and falls in one of its rotation weeks (#126). M8's
    exceptions will sit here too (#176).

    >>> class_occurrences(request.user, datetime.date(2026, 3, 2), datetime.date(2026, 3, 8))
    """
    schedules = ClassSchedule.objects.filter(
        discipline__semester__user=user,
        is_active=True,
    ).select_related("discipline__semester")

    occurrences = []
    for schedule in schedules:
        occurrences.extend(_schedule_occurrences(schedule, start, end))
    return occurrences

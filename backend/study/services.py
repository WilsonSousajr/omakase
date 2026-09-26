"""Study computations that views and other apps call, not reimplement."""

import datetime

from .models import ClassSchedule


def class_occurrences(user, start: datetime.date, end: datetime.date) -> list[dict]:
    """Expand `user`'s active weekly class schedules into dated occurrences.

    Each occurrence is a dict shaped for `ClassOccurrenceSerializer`, one per
    day in `start`..`end` (inclusive) that matches a schedule's weekday and
    lies inside its semester. M8's exceptions will sit here too (#176).

    >>> class_occurrences(request.user, datetime.date(2026, 3, 2), datetime.date(2026, 3, 8))
    """
    schedules = ClassSchedule.objects.filter(
        discipline__semester__user=user,
        is_active=True,
    ).select_related("discipline")

    occurrences = []
    for schedule in schedules:
        # Only generate occurrences within the semester's date range
        semester = schedule.discipline.semester
        effective_start = max(start, semester.start_date)
        effective_end = min(end, semester.end_date)

        if effective_start > effective_end:
            continue

        # Walk days in range, find matching day_of_week
        current = effective_start
        while current <= effective_end:
            if current.weekday() == schedule.day_of_week:
                occurrences.append(
                    {
                        "id": f"{schedule.id}-{current.isoformat()}",
                        "class_schedule_id": schedule.id,
                        "discipline_name": schedule.discipline.name,
                        "discipline_color": schedule.discipline.color,
                        "class_type": schedule.class_type,
                        "location": schedule.location,
                        "date": current,
                        "start_time": schedule.start_time,
                        "end_time": schedule.end_time,
                    }
                )
            current += datetime.timedelta(days=1)
    return occurrences

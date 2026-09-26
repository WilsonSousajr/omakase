"""The daily review's writes and the day's workload, which the views only parse and answer."""

import datetime

from django.db.models import Count, Q, QuerySet, Sum
from django.utils import timezone

from accounts.models import UserProfile
from study.models import StudyBlock
from study.services import class_occurrences
from tasks.models import Task

from .models import DailyReview

REVIEW_FIELDS = ("productivity_rating", "win_of_the_day", "energy", "is_shutdown")


def put_review(user, date: datetime.date, values: dict) -> DailyReview:
    """Create or update `user`'s one review for `date` with `values`.

    Idempotent by the natural key (user, date), so the Mac's outbox can replay
    it: a second shutdown keeps the first `shutdown_at`.

    >>> put_review(request.user, datetime.date(2026, 3, 7), {"energy": 2})
    """
    review, _ = DailyReview.objects.get_or_create(user=user, date=date)
    for field in REVIEW_FIELDS:
        if field in values:
            setattr(review, field, values[field])
    review.shutdown_at = _shutdown_stamp(review)
    review.save()
    return review


def _shutdown_stamp(review: DailyReview) -> datetime.datetime | None:
    if not review.is_shutdown:
        return None
    return review.shutdown_at or timezone.now()


def day_workload(user, day: datetime.date) -> dict:
    """The minutes `user` planned for `day`, against their daily goal (#128).

    Tasks and study blocks count when scheduled on `day`, done or not; items
    carried over from earlier days count only once rescheduled onto it.
    Items without an estimate add nothing and are counted instead, so a
    client can say the total is partial.

    >>> day_workload(request.user, datetime.date(2026, 9, 26))["over_minutes"]
    """
    tasks = _estimate_totals(Task.objects.filter(user=user, scheduled_date=day))
    blocks = _estimate_totals(StudyBlock.objects.filter(discipline__semester__user=user, scheduled_date=day))
    classes = _class_minutes(user, day)
    planned = tasks["minutes"] + blocks["minutes"] + classes
    goal = _goal_minutes(user)
    return {
        "date": day.isoformat(),
        "task_minutes": tasks["minutes"],
        "study_block_minutes": blocks["minutes"],
        "class_minutes": classes,
        "planned_minutes": planned,
        "goal_minutes": goal,
        "over_minutes": planned - goal,
        "unestimated_count": tasks["unestimated"] + blocks["unestimated"],
    }


def _estimate_totals(items: QuerySet) -> dict[str, int]:
    """Sum of `estimated_minutes` over `items`, and how many have none."""
    totals = items.aggregate(
        minutes=Sum("estimated_minutes"), unestimated=Count("pk", filter=Q(estimated_minutes=None))
    )
    return {"minutes": totals["minutes"] or 0, "unestimated": totals["unestimated"]}


def _class_minutes(user, day: datetime.date) -> int:
    """Minutes of `user`'s classes on `day`, from the weekly timetable."""
    return sum(_minutes_between(occ["start_time"], occ["end_time"]) for occ in class_occurrences(user, day, day))


def _minutes_between(start: datetime.time, end: datetime.time) -> int:
    anchor = datetime.date.min
    elapsed = datetime.datetime.combine(anchor, end) - datetime.datetime.combine(anchor, start)
    return int(elapsed.total_seconds() // 60)


def _goal_minutes(user) -> int:
    """The daily work plus study goal in minutes; a missing profile is created, as auth/profile/ does."""
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return int((profile.daily_work_goal_hours + profile.daily_study_goal_hours) * 60)

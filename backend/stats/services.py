"""The daily review's writes that the views only parse and answer."""

import datetime

from django.utils import timezone

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

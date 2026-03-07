import datetime

import pytest

from conftest import DailyReviewFactory, UserFactory
from stats.serializers import DailyReviewSerializer


@pytest.mark.django_db
class TestDailyReviewSerializer:
    def test_serialize_daily_review(self):
        user = UserFactory()
        review = DailyReviewFactory(
            user=user,
            date=datetime.date(2026, 3, 6),
            productivity_rating=4,
            win_of_the_day="Finished the API refactor",
            is_shutdown=True,
        )
        data = DailyReviewSerializer(review).data
        assert str(data["id"]) == str(review.id)
        assert data["date"] == "2026-03-06"
        assert data["productivity_rating"] == 4
        assert data["win_of_the_day"] == "Finished the API refactor"
        assert data["is_shutdown"] is True

    def test_validate_productivity_rating_range(self):
        serializer = DailyReviewSerializer(
            data={"date": "2026-03-06", "productivity_rating": 6}
        )
        assert not serializer.is_valid()
        assert "productivity_rating" in serializer.errors

    def test_validate_productivity_rating_zero(self):
        serializer = DailyReviewSerializer(
            data={"date": "2026-03-06", "productivity_rating": 0}
        )
        assert not serializer.is_valid()
        assert "productivity_rating" in serializer.errors

import datetime

import pytest
from rest_framework import status

from conftest import DailyReviewFactory


@pytest.mark.django_db
class TestDailyReviewViewSet:
    URL = "/api/v1/stats/reviews/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_create_daily_review(self, authenticated_client):
        resp = authenticated_client.post(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["date"] == "2026-03-06"
        assert resp.data["is_shutdown"] is False
        assert resp.data["productivity_rating"] is None

    def test_create_duplicate_date_returns_400(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.post(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_update_review(self, authenticated_client, user):
        review = DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.patch(
            f"{self.URL}{review.id}/",
            {"productivity_rating": 4, "win_of_the_day": "Shipped the feature"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["productivity_rating"] == 4
        assert resp.data["win_of_the_day"] == "Shipped the feature"

    def test_shutdown_sets_timestamp(self, authenticated_client, user):
        review = DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.patch(
            f"{self.URL}{review.id}/",
            {"is_shutdown": True},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["is_shutdown"] is True
        assert resp.data["shutdown_at"] is not None

    def test_list_scoped_to_user(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 5))
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        DailyReviewFactory()  # another user
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

import datetime

import pytest
from rest_framework import status

from conftest import DailyReviewFactory, UserFactory
from stats.models import DailyReview


def _url(day: str) -> str:
    return f"/api/v1/stats/reviews/by-date/{day}/"


@pytest.mark.django_db
class TestReviewByDate:
    def test_put_creates_the_days_review(self, authenticated_client, user):
        resp = authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 4}, format="json")
        assert resp.status_code == status.HTTP_200_OK, resp.data
        assert resp.data["date"] == "2026-03-07" and resp.data["productivity_rating"] == 4
        assert DailyReview.objects.filter(user=user).count() == 1

    def test_replaying_a_put_leaves_one_review_with_the_last_values(self, authenticated_client, user):
        authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 3}, format="json")
        authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 5, "energy": 2}, format="json")
        review = DailyReview.objects.get(user=user)
        assert (review.productivity_rating, review.energy) == (5, 2)

    def test_a_put_leaves_fields_it_omits_alone(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 7), win_of_the_day="shipped")
        authenticated_client.put(_url("2026-03-07"), {"energy": 1}, format="json")
        assert DailyReview.objects.get(user=user).win_of_the_day == "shipped"

    def test_shutdown_is_stamped_by_the_server(self, authenticated_client):
        resp = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        assert resp.data["is_shutdown"] is True and resp.data["shutdown_at"] is not None

    def test_replayed_shutdown_keeps_the_first_stamp(self, authenticated_client, user):
        # Review Focus 5: the outbox may replay a write the server already applied.
        first = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        again = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        assert again.data["shutdown_at"] == first.data["shutdown_at"]

    def test_the_path_date_wins_over_a_body_date(self, authenticated_client, user):
        authenticated_client.put(_url("2026-03-07"), {"date": "2026-01-01", "energy": 2}, format="json")
        assert DailyReview.objects.get(user=user).date == datetime.date(2026, 3, 7)

    def test_a_bad_date_is_a_400_naming_it(self, authenticated_client):
        resp = authenticated_client.put(_url("07-03-2026"), {"energy": 2}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "07-03-2026" in str(resp.data)

    def test_another_users_review_is_untouched(self, authenticated_client, user):
        stranger = DailyReviewFactory(user=UserFactory(), date=datetime.date(2026, 3, 7), energy=3)
        authenticated_client.put(_url("2026-03-07"), {"energy": 1}, format="json")
        stranger.refresh_from_db()
        assert stranger.energy == 3
        assert DailyReview.objects.filter(user=user).count() == 1

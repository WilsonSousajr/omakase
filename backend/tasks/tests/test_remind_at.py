"""A task's "remind me at" (#127, M3.6 spec §1).

remind_at is an instant: the client sends it with its UTC offset, and the
API returns the same instant, whatever offset it renders it in.
"""

import datetime

import pytest
from django.utils.dateparse import parse_datetime
from rest_framework import status

from conftest import TaskFactory, UserFactory
from tasks.models import Task

DAY = datetime.date(2026, 3, 7)
SAO_PAULO_NINE = "2026-09-27T09:00:00-03:00"


def _instant(raw: str) -> datetime.datetime:
    return parse_datetime(raw)


@pytest.mark.django_db
class TestRemindAt:
    def test_a_new_task_has_no_reminder(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.get(f"/api/v1/tasks/{task.pk}/")
        assert resp.data["remind_at"] is None

    def test_patch_keeps_the_instant_across_offsets(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.patch(f"/api/v1/tasks/{task.pk}/", {"remind_at": SAO_PAULO_NINE}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert _instant(resp.data["remind_at"]) == _instant(SAO_PAULO_NINE)
        task.refresh_from_db()
        assert task.remind_at == _instant(SAO_PAULO_NINE)

    def test_null_clears_it(self, authenticated_client, user):
        task = TaskFactory(user=user, remind_at=_instant(SAO_PAULO_NINE))
        resp = authenticated_client.patch(f"/api/v1/tasks/{task.pk}/", {"remind_at": None}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["remind_at"] is None
        task.refresh_from_db()
        assert task.remind_at is None

    def test_create_accepts_it(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/tasks/", {"title": "Call", "remind_at": SAO_PAULO_NINE}, format="json"
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert Task.objects.get(pk=resp.data["id"]).remind_at == _instant(SAO_PAULO_NINE)

    def test_today_returns_it(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=DAY, remind_at=_instant(SAO_PAULO_NINE))
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert _instant(resp.data["results"][0]["remind_at"]) == _instant(SAO_PAULO_NINE)

    def test_carried_over_returns_it(self, authenticated_client, user):
        yesterday = DAY - datetime.timedelta(days=1)
        TaskFactory(user=user, scheduled_date=yesterday, is_completed=False, remind_at=_instant(SAO_PAULO_NINE))
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-07")
        assert _instant(resp.data[0]["remind_at"]) == _instant(SAO_PAULO_NINE)

    def test_another_users_task_is_a_404(self, authenticated_client):
        theirs = TaskFactory(user=UserFactory())
        resp = authenticated_client.patch(f"/api/v1/tasks/{theirs.pk}/", {"remind_at": SAO_PAULO_NINE}, format="json")
        assert resp.status_code == status.HTTP_404_NOT_FOUND
        theirs.refresh_from_db()
        assert theirs.remind_at is None

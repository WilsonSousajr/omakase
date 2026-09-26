import datetime

import pytest
from django.utils import timezone
from rest_framework import status

from conftest import DisciplineFactory, SemesterFactory, StudyBlockFactory, TaskFactory, TimeBlockFactory, UserFactory

URL = "/api/v1/pomodoro/sessions/"


def _post(client, **fields):
    return client.post(URL, {"session_type": "focus", "duration_minutes": 25, **fields}, format="json")


@pytest.mark.django_db
class TestSessionsKeepTheMacsClock:
    def test_a_client_started_at_is_stored_as_sent(self, authenticated_client):
        started = (timezone.now() - datetime.timedelta(hours=3)).replace(microsecond=0)
        resp = _post(authenticated_client, started_at=started.isoformat())
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["started_at"] == started.astimezone(datetime.UTC).isoformat().replace("+00:00", "Z")

    def test_started_at_with_an_offset_is_stored_in_utc(self, authenticated_client):
        plus_two = datetime.timezone(datetime.timedelta(hours=2))
        local = (timezone.now() - datetime.timedelta(hours=1)).astimezone(plus_two)
        resp = _post(authenticated_client, started_at=local.isoformat())
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["started_at"].endswith("Z")

    def test_an_omitted_started_at_is_still_stamped(self, authenticated_client):
        resp = _post(authenticated_client)
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["started_at"] is not None

    def test_a_future_started_at_is_a_400_naming_it(self, authenticated_client):
        future = timezone.now() + datetime.timedelta(minutes=10)
        resp = _post(authenticated_client, started_at=future.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "in the future" in str(resp.data["started_at"])

    def test_a_started_at_older_than_eight_days_is_a_400(self, authenticated_client):
        old = timezone.now() - datetime.timedelta(days=9)
        resp = _post(authenticated_client, started_at=old.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "older than 8 days" in str(resp.data["started_at"])

    def test_ended_before_started_is_a_400_naming_both(self, authenticated_client):
        started = timezone.now() - datetime.timedelta(minutes=30)
        ended = started - datetime.timedelta(minutes=1)
        resp = _post(authenticated_client, started_at=started.isoformat(), ended_at=ended.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "is before started_at" in str(resp.data["ended_at"])


@pytest.mark.django_db
class TestSessionsRecordTheirBlock:
    def test_a_session_records_its_task_block(self, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user))
        resp = _post(authenticated_client, time_block=str(block.pk))
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert str(resp.data["time_block"]) == str(block.pk)

    def test_a_session_records_its_study_block(self, authenticated_client, user):
        semester = SemesterFactory(user=user)
        study = StudyBlockFactory(discipline=DisciplineFactory(semester=semester))
        block = TimeBlockFactory(task=None, study_block=study)
        resp = _post(authenticated_client, time_block=str(block.pk))
        assert resp.status_code == status.HTTP_201_CREATED, resp.data

    def test_another_users_block_is_refused(self, authenticated_client):
        # Invariant 1 needs two users: a one-user test cannot see the leak.
        stranger_block = TimeBlockFactory(task=TaskFactory(user=UserFactory()))
        resp = _post(authenticated_client, time_block=str(stranger_block.pk))
        assert resp.status_code == status.HTTP_403_FORBIDDEN

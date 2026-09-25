"""Idempotency-Key through the real endpoints (#77)."""

import datetime
import threading
import uuid

import pytest
from django.db import connection
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from conftest import UserFactory
from idempotency.models import IdempotencyRecord
from tasks.models import Task

TASKS = "/api/v1/tasks/"


def _client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


def _post(client: APIClient, key: str, body: dict | None = None, url: str = TASKS):
    return client.post(url, body or {"title": "Buy milk"}, format="json", HTTP_IDEMPOTENCY_KEY=key)


@pytest.mark.django_db
class TestIdempotentCreate:
    def test_same_key_twice_creates_once_and_replays_the_response(self, authenticated_client, user):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key)
        second = _post(authenticated_client, key)
        assert first.status_code == second.status_code == 201
        assert second.data == first.data
        assert second["Idempotent-Replayed"] == "true"
        assert Task.objects.filter(user=user).count() == 1

    def test_different_keys_create_twice(self, authenticated_client, user):
        _post(authenticated_client, str(uuid.uuid4()))
        _post(authenticated_client, str(uuid.uuid4()))
        assert Task.objects.filter(user=user).count() == 2

    def test_no_key_behaves_as_before(self, authenticated_client, user):
        authenticated_client.post(TASKS, {"title": "a"}, format="json")
        authenticated_client.post(TASKS, {"title": "a"}, format="json")
        assert Task.objects.filter(user=user).count() == 2

    def test_same_key_different_path_is_422(self, authenticated_client):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        resp = _post(
            authenticated_client,
            key,
            {"session_type": "focus", "duration_minutes": 25},
            url="/api/v1/pomodoro/sessions/",
        )
        assert resp.status_code == 422
        assert key in resp.data["detail"] and "/api/v1/tasks/" in resp.data["detail"]

    def test_same_key_different_user_is_independent(self, authenticated_client, user):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        other = UserFactory()
        resp = _post(_client_for(other), key)
        assert resp.status_code == 201
        assert "Idempotent-Replayed" not in resp
        assert Task.objects.filter(user=other).count() == 1

    def test_validation_error_is_stored_and_replayed(self, authenticated_client, user):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key, {"title": ""})
        second = _post(authenticated_client, key, {"title": "now valid"})
        assert first.status_code == second.status_code == 400
        assert second["Idempotent-Replayed"] == "true"
        assert Task.objects.filter(user=user).count() == 0

    @pytest.mark.parametrize("key", ["", "x" * 65, "has space", "semi;colon"])
    def test_rejects_malformed_key(self, authenticated_client, key):
        resp = _post(authenticated_client, key)
        assert resp.status_code == 400
        assert "Idempotency-Key" in resp.data["detail"]
        assert IdempotencyRecord.objects.count() == 0

    def test_expired_record_acts_again(self, authenticated_client, user):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        IdempotencyRecord.objects.update(created_at=timezone.now() - datetime.timedelta(days=8))
        resp = _post(authenticated_client, key)
        assert resp.status_code == 201 and "Idempotent-Replayed" not in resp
        assert Task.objects.filter(user=user).count() == 2

    @pytest.mark.parametrize(
        "url,body",
        [
            ("/api/v1/pomodoro/sessions/", {"session_type": "focus", "duration_minutes": 25}),
            ("/api/v1/stats/reviews/", {"date": "2026-03-07", "productivity_rating": 4}),
        ],
    )
    def test_the_other_outbox_creates_are_idempotent(self, authenticated_client, url, body):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key, body, url=url)
        second = _post(authenticated_client, key, body, url=url)
        assert first.status_code == 201, first.data
        assert second["Idempotent-Replayed"] == "true" and second.data == first.data

    def test_patch_tolerates_the_header(self, authenticated_client, task):
        resp = authenticated_client.patch(
            f"{TASKS}{task.pk}/", {"is_completed": True}, format="json", HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4())
        )
        assert resp.status_code == 200


@pytest.mark.django_db(transaction=True)
def test_concurrent_same_key_creates_once(user):
    # Review Focus 2: a retry fired while the first attempt still runs. The
    # unique (user, key) index makes the second insert wait for the first
    # transaction, then replay it.
    key, results = str(uuid.uuid4()), []

    def attempt() -> None:
        results.append(_post(_client_for(user), key).status_code)
        connection.close()

    threads = [threading.Thread(target=attempt) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert sorted(results) == [201, 201]
    assert Task.objects.filter(user=user).count() == 1

"""run_once below the endpoints: what is not stored (#77)."""

import uuid

import pytest
from rest_framework.response import Response

from idempotency.models import IdempotencyRecord
from idempotency.services import run_once


@pytest.mark.django_db
def test_a_5xx_is_not_stored_so_a_retry_acts(user):
    # A server error is not an answer: the outbox retries it, and the retry
    # must run the create again rather than replay the failure.
    key, calls = str(uuid.uuid4()), []

    def perform() -> Response:
        calls.append(1)
        return Response({"detail": "boom"}, status=503 if len(calls) == 1 else 201)

    first = run_once(user, key, "POST", "/api/v1/tasks/", perform)
    second = run_once(user, key, "POST", "/api/v1/tasks/", perform)
    assert (first.status_code, second.status_code) == (503, 201)
    assert len(calls) == 2
    assert IdempotencyRecord.objects.get(user=user, key=key).status_code == 201

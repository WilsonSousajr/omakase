"""Contract fixtures for the Swift client (#78).

Each test calls a real endpoint the Mac app uses and compares the response's
*shape* - keys and JSON types, recursively - with the fixture the Swift DTO
tests decode. A shape change fails here, in the PR that makes it. To accept a
deliberate change, regenerate and commit the fixtures in the same PR:

    docker-compose exec -e WRITE_CONTRACT_FIXTURES=1 backend pytest tools/tests/test_contract_fixtures.py
"""

import datetime
import json
import os
from pathlib import Path
from unittest.mock import patch

import pytest

from accounts.tests.fakes import FakeGoogleVerifier
from conftest import DailyReviewFactory, SubtaskFactory, TagFactory, TaskFactory, TimeBlockFactory

REPO = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[3]))
FIXTURES = REPO / "apps" / "apple" / "Fixtures"
WRITE = os.environ.get("WRITE_CONTRACT_FIXTURES") == "1"
TOKEN_KEYS = {"access", "refresh"}
REDACTED_JWT = "redacted.jwt.token"


def shape(value: object) -> object:
    """Keys and JSON types, not values: what a decoder depends on."""
    if isinstance(value, dict):
        return {key: shape(item) for key, item in sorted(value.items())}
    if isinstance(value, list):
        return [shape(value[0])] if value else []
    return type(value).__name__


def _redacted(body: object) -> object:
    """The body with every JWT replaced: a committed fixture never holds a live token."""
    if isinstance(body, dict):
        return {key: REDACTED_JWT if key in TOKEN_KEYS else _redacted(item) for key, item in body.items()}
    if isinstance(body, list):
        return [_redacted(item) for item in body]
    return body


def check_fixture(name: str, body: object) -> None:
    path = FIXTURES / f"{name}.json"
    if WRITE:
        path.write_text(json.dumps(_redacted(body), indent=2, sort_keys=True, default=str) + "\n")
        return
    assert path.exists(), f"{path} is missing; run with WRITE_CONTRACT_FIXTURES=1 and commit it"
    stored = json.loads(path.read_text())
    assert shape(json.loads(json.dumps(body, default=str))) == shape(stored), (
        f"{name}: the response shape no longer matches {path.name}. If deliberate, regenerate "
        "the fixtures with WRITE_CONTRACT_FIXTURES=1 and update the Swift DTOs in the same PR."
    )


def _body(response) -> object:
    return json.loads(response.content)


@pytest.mark.django_db
class TestContractFixtures:
    def test_auth_google(self, api_client, settings):
        settings.GOOGLE_CLIENT_IDS = ["mac.apps"]
        idinfo = {"email": "ada@example.com", "email_verified": True, "given_name": "Ada", "family_name": "L"}
        with patch("accounts.views.id_token.verify_oauth2_token", new=FakeGoogleVerifier(idinfo)):
            resp = api_client.post("/api/v1/auth/google/", {"credential": "tok"}, format="json")
        assert resp.status_code == 200
        check_fixture("auth_google", _body(resp))

    def test_token_refresh(self, api_client, user):
        from rest_framework_simplejwt.tokens import RefreshToken

        resp = api_client.post(
            "/api/v1/auth/token/refresh/", {"refresh": str(RefreshToken.for_user(user))}, format="json"
        )
        assert resp.status_code == 200
        check_fixture("token_refresh", _body(resp))

    def test_auth_me(self, authenticated_client):
        resp = authenticated_client.get("/api/v1/auth/me/")
        assert resp.status_code == 200
        check_fixture("auth_me", _body(resp))

    def test_tasks_today(self, authenticated_client, user):
        task = TaskFactory(
            user=user,
            scheduled_date=datetime.date(2026, 3, 7),
            due_date=datetime.date(2026, 3, 9),
            estimated_minutes=25,
            project=None,
            discipline=None,
        )
        task.tags.add(TagFactory(user=user))
        SubtaskFactory(task=task, title="Outline")
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("tasks_today", _body(resp))

    def test_task_patch(self, authenticated_client, user):
        task = TaskFactory(
            user=user,
            scheduled_date=datetime.date(2026, 3, 7),
            due_date=None,
            estimated_minutes=None,
            project=None,
            discipline=None,
        )
        resp = authenticated_client.patch(f"/api/v1/tasks/{task.pk}/", {"is_completed": True}, format="json")
        assert resp.status_code == 200
        check_fixture("task_patch", _body(resp))

    def test_stats_review_list(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 7), productivity_rating=4, energy=2)
        resp = authenticated_client.get("/api/v1/stats/reviews/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("stats_review_list", _body(resp))

    def test_tasks_carried_over(self, authenticated_client, user):
        task = TaskFactory(
            user=user,
            scheduled_date=datetime.date(2026, 3, 6),
            is_completed=False,
            project=None,
            discipline=None,
        )
        SubtaskFactory(task=task, title="Outline")
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("tasks_carried_over", _body(resp))

    # The fixture's dates are fixed, so "now" is frozen inside the session window (#142).
    @patch("pomodoro.serializers.timezone.now", return_value=datetime.datetime(2026, 3, 7, 10, tzinfo=datetime.UTC))
    def test_pomodoro_session_create(self, _now, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user, project=None, discipline=None))
        resp = authenticated_client.post(
            "/api/v1/pomodoro/sessions/",
            {
                "task": str(block.task.pk),
                "time_block": str(block.pk),
                "session_type": "focus",
                "duration_minutes": 25,
                "started_at": "2026-03-07T09:00:00Z",
                "ended_at": "2026-03-07T09:25:00Z",
                "completed": True,
            },
            format="json",
        )
        assert resp.status_code == 201, resp.content
        check_fixture("pomodoro_session", _body(resp))


def test_fixtures_hold_no_live_tokens():
    # The fixtures are committed; a JWT signed with this environment's
    # SECRET_KEY must never be (#78). Shape is all the Swift tests need.
    for path in FIXTURES.glob("*.json"):
        assert "eyJ" not in path.read_text(), f"{path.name} holds a live JWT; write it through _redacted()"

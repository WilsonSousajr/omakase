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
from conftest import (
    ClassCancellationFactory,
    ClassScheduleFactory,
    DailyReviewFactory,
    DisciplineFactory,
    HolidayFactory,
    PomodoroSessionFactory,
    ProjectFactory,
    SemesterFactory,
    StudyBlockFactory,
    SubtaskFactory,
    TagFactory,
    TaskFactory,
    TimeBlockFactory,
    WorkspaceFactory,
)
from tasks.models import TaskRecurrence

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


def _series(user, **rule):
    template = TaskFactory(user=user, title="Stand-up", estimated_minutes=15, project=None, discipline=None)
    TaskRecurrence.objects.create(task=template, **{"freq": "weekly", **rule})
    return template


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
        # A series' computed occurrence is task-shaped with id null (#124).
        _series(user, starts_on=datetime.date(2026, 3, 7))
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("tasks_today", _body(resp))

    def test_tasks_occurrences_range(self, authenticated_client, user):
        # Plan reads a week of rows and computed occurrences (#124).
        template = _series(user, starts_on=datetime.date(2026, 3, 2), weekdays=[0, 2])
        TaskFactory(
            user=user,
            series=template,
            occurrence_date=datetime.date(2026, 3, 2),
            scheduled_date=datetime.date(2026, 3, 2),
            project=None,
            discipline=None,
        )
        resp = authenticated_client.get("/api/v1/tasks/occurrences/?date_from=2026-03-02&date_to=2026-03-08")
        assert resp.status_code == 200
        check_fixture("tasks_occurrences_range", _body(resp))

    def test_task_occurrence(self, authenticated_client, user):
        # The Mac's task.materialize outbox write (#124, #206).
        template = _series(user, starts_on=datetime.date(2026, 3, 2), weekdays=[0, 2])
        resp = authenticated_client.put(
            f"/api/v1/tasks/{template.pk}/occurrences/2026-03-04/", {"is_completed": True}, format="json"
        )
        assert resp.status_code == 201, resp.content
        check_fixture("task_occurrence", _body(resp))

    def test_task_recurrence(self, authenticated_client, user):
        # The Mac's task.recurrence outbox write (#124, #206): the task, now the series' first occurrence.
        task = TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 2), project=None, discipline=None)
        resp = authenticated_client.put(
            f"/api/v1/tasks/{task.pk}/recurrence/",
            {"freq": "weekly", "interval": 1, "weekdays": [0, 2], "starts_on": "2026-03-02", "until": "2026-06-30"},
            format="json",
        )
        assert resp.status_code == 200, resp.content
        check_fixture("task_recurrence", _body(resp))

    def test_task_patch(self, authenticated_client, user):
        task = TaskFactory(
            user=user,
            scheduled_date=datetime.date(2026, 3, 7),
            due_date=None,
            estimated_minutes=None,
            project=None,
            discipline=None,
        )
        # remind_at is set so the Swift test decodes a date, not only a null (#127).
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/", {"is_completed": True, "remind_at": "2026-03-07T12:00:00Z"}, format="json"
        )
        assert resp.status_code == 200
        check_fixture("task_patch", _body(resp))

    def test_stats_review_list(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 7), productivity_rating=4, energy=2)
        resp = authenticated_client.get("/api/v1/stats/reviews/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("stats_review_list", _body(resp))

    def test_review_by_date(self, authenticated_client):
        resp = authenticated_client.put(
            "/api/v1/stats/reviews/by-date/2026-03-07/",
            {"productivity_rating": 4, "win_of_the_day": "Shipped M3.1", "energy": 2},
            format="json",
        )
        assert resp.status_code == 200
        check_fixture("review_by_date", _body(resp))

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

    def test_timeblocks_day(self, authenticated_client, user):
        TimeBlockFactory(
            task=TaskFactory(user=user, project=None, discipline=None),
            date=datetime.date(2026, 3, 7),
            notes="Draft",
            session_rating=4,
        )
        resp = authenticated_client.get("/api/v1/timeblocks/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("timeblocks_day", _body(resp))

    def test_timeblock_create(self, authenticated_client, user):
        # Plan's block.create goes through the outbox, so it is sent with a key (#199).
        task = TaskFactory(user=user, project=None, discipline=None)
        resp = authenticated_client.post(
            "/api/v1/timeblocks/",
            {"task": str(task.pk), "date": "2026-03-07", "start_time": "09:00", "end_time": "10:00"},
            format="json",
            HTTP_IDEMPOTENCY_KEY="b0c4e2d6-7f1a-4c3e-9d2b-5a6f8e1c0d37",
        )
        assert resp.status_code == 201, resp.content
        check_fixture("timeblock_create", _body(resp))

    def test_pomodoro_sessions_range(self, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user, project=None, discipline=None))
        PomodoroSessionFactory(
            task=block.task,
            time_block=block,
            started_at=datetime.datetime(2026, 3, 7, 9, tzinfo=datetime.UTC),
            ended_at=datetime.datetime(2026, 3, 7, 9, 25, tzinfo=datetime.UTC),
            completed=True,
        )
        resp = authenticated_client.get(
            "/api/v1/pomodoro/sessions/",
            {"started_after": "2026-03-02T00:00:00-03:00", "started_before": "2026-03-09T00:00:00-03:00"},
        )
        assert resp.status_code == 200
        check_fixture("pomodoro_sessions_range", _body(resp))

    def test_studyblocks_day(self, authenticated_client, user):
        discipline = DisciplineFactory(semester=SemesterFactory(user=user))
        StudyBlockFactory(discipline=discipline, scheduled_date=datetime.date(2026, 3, 7), estimated_minutes=45)
        resp = authenticated_client.get("/api/v1/study/studyblocks/?scheduled_date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("studyblocks_day", _body(resp))

    def test_study_class_occurrences(self, authenticated_client, user):
        # Plan draws classes from this; the Mac decodes it (#126).
        semester = SemesterFactory(user=user, rotation_weeks=2, rotation_anchor=datetime.date(2026, 3, 2))
        schedule = ClassScheduleFactory(
            discipline=DisciplineFactory(semester=semester), day_of_week=0, rotation_weeks_on=[1]
        )
        # A cancelled class is returned marked, not omitted (#125).
        ClassCancellationFactory(class_schedule=schedule, date=datetime.date(2026, 3, 2))
        resp = authenticated_client.get("/api/v1/study/class-occurrences/?date_from=2026-03-02&date_to=2026-03-08")
        assert resp.status_code == 200
        check_fixture("study_class_occurrences", _body(resp))

    def test_study_class_cancellation(self, authenticated_client, user):
        # The Mac's class.cancel outbox write (#125).
        schedule = ClassScheduleFactory(
            discipline=DisciplineFactory(semester=SemesterFactory(user=user)), day_of_week=0
        )
        resp = authenticated_client.put(f"/api/v1/study/classschedules/{schedule.pk}/cancellations/2026-03-09/")
        assert resp.status_code == 201, resp.content
        check_fixture("study_class_cancellation", _body(resp))

    def test_stats_workload(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 2), estimated_minutes=50, project=None)
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 2), estimated_minutes=None, project=None)
        resp = authenticated_client.get("/api/v1/stats/workload/?date=2026-03-02")
        assert resp.status_code == 200
        check_fixture("stats_workload", _body(resp))

    def test_profile(self, authenticated_client):
        resp = authenticated_client.get("/api/v1/auth/profile/")
        assert resp.status_code == 200
        check_fixture("profile", _body(resp))

    def test_profile_patch(self, authenticated_client):
        # Settings writes each change as a profile PATCH (#223); both reminders
        # are set so the Swift test decodes values, not only nulls.
        resp = authenticated_client.patch(
            "/api/v1/auth/profile/",
            {"week_starts_on": "sunday", "block_reminder_minutes": 10, "shutdown_reminder_time": "18:30:00"},
            format="json",
        )
        assert resp.status_code == 200, resp.content
        check_fixture("profile_patch", _body(resp))

    def test_auth_me_patch(self, authenticated_client):
        resp = authenticated_client.patch("/api/v1/auth/me/", {"first_name": "Ada"}, format="json")
        assert resp.status_code == 200, resp.content
        check_fixture("auth_me_patch", _body(resp))


@pytest.mark.django_db
class TestLibraryContractFixtures:
    """The lists LibrarySync reads for Projects, Study and the Inbox (#223)."""

    def test_workspaces_list(self, authenticated_client, user):
        workspace = WorkspaceFactory(user=user, name="Client work")
        ProjectFactory(workspace=workspace)
        resp = authenticated_client.get("/api/v1/workspaces/")
        assert resp.status_code == 200
        check_fixture("workspaces_list", _body(resp))

    def test_projects_list(self, authenticated_client, user):
        project = ProjectFactory(workspace=WorkspaceFactory(user=user), due_date=datetime.date(2026, 6, 30))
        TaskFactory(user=user, project=project)
        resp = authenticated_client.get("/api/v1/projects/")
        assert resp.status_code == 200
        check_fixture("projects_list", _body(resp))

    def test_tasks_unscheduled(self, authenticated_client, user):
        # The Inbox (#223): no date, and neither series templates nor skipped rows.
        TaskFactory(user=user, scheduled_date=None, estimated_minutes=25, project=None, discipline=None)
        resp = authenticated_client.get("/api/v1/tasks/?unscheduled=true&is_completed=false")
        assert resp.status_code == 200
        check_fixture("tasks_unscheduled", _body(resp))

    def test_study_semesters_list(self, authenticated_client, user):
        SemesterFactory(user=user, rotation_weeks=2, rotation_anchor=datetime.date(2026, 3, 2))
        resp = authenticated_client.get("/api/v1/study/semesters/")
        assert resp.status_code == 200
        check_fixture("study_semesters_list", _body(resp))

    def test_study_disciplines_list(self, authenticated_client, user):
        DisciplineFactory(semester=SemesterFactory(user=user), professor="Dr. Lovelace", credits=4, target_grade=8.5)
        resp = authenticated_client.get("/api/v1/study/disciplines/")
        assert resp.status_code == 200
        check_fixture("study_disciplines_list", _body(resp))

    def test_study_classschedules_list(self, authenticated_client, user):
        semester = SemesterFactory(user=user, rotation_weeks=2, rotation_anchor=datetime.date(2026, 3, 2))
        ClassScheduleFactory(discipline=DisciplineFactory(semester=semester), rotation_weeks_on=[1])
        resp = authenticated_client.get("/api/v1/study/classschedules/")
        assert resp.status_code == 200
        check_fixture("study_classschedules_list", _body(resp))

    def test_study_holidays_list(self, authenticated_client, user):
        HolidayFactory(semester=SemesterFactory(user=user), name="Easter")
        resp = authenticated_client.get("/api/v1/study/holidays/")
        assert resp.status_code == 200
        check_fixture("study_holidays_list", _body(resp))


def test_fixtures_hold_no_live_tokens():
    # The fixtures are committed; a JWT signed with this environment's
    # SECRET_KEY must never be (#78). Shape is all the Swift tests need.
    for path in FIXTURES.glob("*.json"):
        assert "eyJ" not in path.read_text(), f"{path.name} holds a live JWT; write it through _redacted()"

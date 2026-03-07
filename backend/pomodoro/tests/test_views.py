import pytest
from rest_framework import status

from conftest import PomodoroSessionFactory, TaskFactory


@pytest.mark.django_db
class TestPomodoroSessionViewSet:
    def test_list_sessions(self, authenticated_client, user):
        PomodoroSessionFactory.create_batch(2, user=user, task__user=user)
        resp = authenticated_client.get("/api/v1/pomodoro/sessions/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_list_sessions_scoped_to_user(self, authenticated_client, user):
        PomodoroSessionFactory.create_batch(2, user=user, task__user=user)
        PomodoroSessionFactory.create_batch(3)  # different user
        resp = authenticated_client.get("/api/v1/pomodoro/sessions/")
        assert resp.data["count"] == 2

    def test_create_session_with_task(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/pomodoro/sessions/",
            {
                "task": str(task.pk),
                "session_type": "focus",
                "duration_minutes": 25,
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert str(resp.data["task"]) == str(task.pk)

    def test_create_session_without_task(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/pomodoro/sessions/",
            {"session_type": "short_break", "duration_minutes": 5},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["task"] is None

    def test_create_custom_duration(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/pomodoro/sessions/",
            {"session_type": "focus", "duration_minutes": 50},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["duration_minutes"] == 50

    def test_retrieve_session(self, authenticated_client, user):
        session = PomodoroSessionFactory(user=user, task__user=user)
        resp = authenticated_client.get(f"/api/v1/pomodoro/sessions/{session.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["id"] == str(session.pk)

    def test_complete_session(self, authenticated_client, user):
        session = PomodoroSessionFactory(completed=False, user=user, task__user=user)
        resp = authenticated_client.patch(
            f"/api/v1/pomodoro/sessions/{session.pk}/",
            {"completed": True, "ended_at": "2025-01-15T10:30:00Z"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed"] is True
        assert resp.data["ended_at"] is not None

    def test_delete_not_allowed(self, authenticated_client, user):
        session = PomodoroSessionFactory(user=user, task__user=user)
        resp = authenticated_client.delete(f"/api/v1/pomodoro/sessions/{session.pk}/")
        assert resp.status_code == status.HTTP_405_METHOD_NOT_ALLOWED

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/pomodoro/sessions/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

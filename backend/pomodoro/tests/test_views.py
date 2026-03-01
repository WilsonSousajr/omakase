import pytest
from rest_framework import status

from conftest import PomodoroSessionFactory, TaskFactory


@pytest.mark.django_db
class TestPomodoroSessionViewSet:
    def test_list_sessions(self, api_client):
        PomodoroSessionFactory.create_batch(2)
        resp = api_client.get("/api/v1/pomodoro/sessions/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_create_session_with_task(self, api_client):
        task = TaskFactory()
        resp = api_client.post(
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

    def test_create_session_without_task(self, api_client):
        resp = api_client.post(
            "/api/v1/pomodoro/sessions/",
            {"session_type": "short_break", "duration_minutes": 5},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["task"] is None

    def test_create_custom_duration(self, api_client):
        resp = api_client.post(
            "/api/v1/pomodoro/sessions/",
            {"session_type": "focus", "duration_minutes": 50},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["duration_minutes"] == 50

    def test_retrieve_session(self, api_client):
        session = PomodoroSessionFactory()
        resp = api_client.get(f"/api/v1/pomodoro/sessions/{session.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["id"] == str(session.pk)

    def test_complete_session(self, api_client):
        session = PomodoroSessionFactory(completed=False)
        resp = api_client.patch(
            f"/api/v1/pomodoro/sessions/{session.pk}/",
            {"completed": True, "ended_at": "2025-01-15T10:30:00Z"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed"] is True
        assert resp.data["ended_at"] is not None

    def test_delete_not_allowed(self, api_client):
        session = PomodoroSessionFactory()
        resp = api_client.delete(f"/api/v1/pomodoro/sessions/{session.pk}/")
        assert resp.status_code == status.HTTP_405_METHOD_NOT_ALLOWED

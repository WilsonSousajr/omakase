import pytest

from conftest import PomodoroSessionFactory, TaskFactory
from pomodoro.models import PomodoroSession


@pytest.mark.django_db
class TestPomodoroSession:
    def test_creation(self):
        session = PomodoroSessionFactory()
        assert session.pk is not None

    def test_defaults(self):
        session = PomodoroSessionFactory()
        assert session.session_type == "focus"
        assert session.duration_minutes == 25
        assert session.completed is False
        assert session.ended_at is None

    def test_optional_task(self):
        session = PomodoroSessionFactory(task=None)
        assert session.task is None

    def test_set_null_on_task_delete(self):
        task = TaskFactory()
        session = PomodoroSessionFactory(task=task)
        task.delete()
        session.refresh_from_db()
        assert session.task is None

    def test_ordering_by_started_at_desc(self):
        s1 = PomodoroSessionFactory()
        s2 = PomodoroSessionFactory()
        sessions = list(PomodoroSession.objects.all())
        assert sessions[0].started_at >= sessions[1].started_at

    def test_str_representation_with_task(self):
        task = TaskFactory(title="Write docs")
        session = PomodoroSessionFactory(task=task, session_type="focus")
        assert "Focus" in str(session)
        assert "Write docs" in str(session)

    def test_str_representation_without_task(self):
        session = PomodoroSessionFactory(task=None)
        assert "No task" in str(session)

import datetime
import factory
import pytest
from rest_framework.test import APIClient

from tasks.models import Tag, Task, TimeBlock
from pomodoro.models import PomodoroSession


class TagFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Tag

    name = factory.Sequence(lambda n: f"Tag {n}")
    color = "#6366f1"
    area = "work"


class TaskFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Task

    title = factory.Sequence(lambda n: f"Task {n}")
    priority = "medium"
    kanban_status = "todo"

    @factory.post_generation
    def tags(self, create, extracted, **kwargs):
        if not create or not extracted:
            return
        self.tags.add(*extracted)


class TimeBlockFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = TimeBlock

    task = factory.SubFactory(TaskFactory)
    date = datetime.date(2025, 1, 15)
    start_time = datetime.time(9, 0)
    end_time = datetime.time(10, 0)


class PomodoroSessionFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = PomodoroSession

    task = factory.SubFactory(TaskFactory)
    session_type = "focus"
    duration_minutes = 25


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def tag(db):
    return TagFactory()


@pytest.fixture
def task(db):
    return TaskFactory()


@pytest.fixture
def time_block(db):
    return TimeBlockFactory()


@pytest.fixture
def pomodoro_session(db):
    return PomodoroSessionFactory()

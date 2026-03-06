import datetime

import factory
import pytest
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from pomodoro.models import PomodoroSession
from stats.models import DailyReview
from study.models import ClassSchedule, Discipline, Semester, StudyBlock
from tasks.models import Project, Tag, Task, TimeBlock, Workspace


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    username = factory.Sequence(lambda n: f"user{n}")
    email = factory.LazyAttribute(lambda obj: f"{obj.username}@example.com")

    @factory.post_generation
    def password(self, create, extracted, **kwargs):
        password = extracted or "testpass123"
        self.set_password(password)
        if create:
            self.save()


class WorkspaceFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Workspace

    user = factory.LazyFunction(lambda: UserFactory())
    name = factory.Sequence(lambda n: f"Workspace {n}")
    color = "#a3a3a3"


class ProjectFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Project

    workspace = factory.SubFactory(WorkspaceFactory)
    name = factory.Sequence(lambda n: f"Project {n}")
    color = "#a3a3a3"
    status = "active"


class TagFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Tag

    user = factory.LazyFunction(lambda: UserFactory())
    name = factory.Sequence(lambda n: f"Tag {n}")
    color = "#6366f1"
    area = "work"


class TaskFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Task

    user = factory.LazyFunction(lambda: UserFactory())
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

    user = factory.LazyAttribute(lambda obj: obj.task.user if obj.task else UserFactory())
    task = factory.SubFactory(TaskFactory)
    session_type = "focus"
    duration_minutes = 25


class SemesterFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Semester

    user = factory.LazyFunction(lambda: UserFactory())
    name = factory.Sequence(lambda n: f"Semester {n}")
    institution = "Test University"
    start_date = datetime.date(2026, 3, 1)
    end_date = datetime.date(2026, 7, 15)
    status = "active"


class DisciplineFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Discipline

    semester = factory.SubFactory(SemesterFactory)
    name = factory.Sequence(lambda n: f"Discipline {n}")
    code = factory.Sequence(lambda n: f"DISC{n:03d}")
    color = "#a3a3a3"
    status = "active"


class StudyBlockFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = StudyBlock

    discipline = factory.SubFactory(DisciplineFactory)
    title = factory.Sequence(lambda n: f"Study Block {n}")
    block_type = "theory"
    priority = "medium"
    status = "planned"


class ClassScheduleFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = ClassSchedule

    discipline = factory.SubFactory(DisciplineFactory)
    day_of_week = 0  # Monday
    start_time = datetime.time(10, 0)
    end_time = datetime.time(11, 40)
    class_type = "lecture"
    location = "Room 101"
    is_active = True


class DailyReviewFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = DailyReview

    user = factory.LazyFunction(lambda: UserFactory())
    date = datetime.date.today()
    productivity_rating = None
    win_of_the_day = ""
    is_shutdown = False


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def authenticated_client(user):
    client = APIClient()
    token = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(token.access_token)}")
    return client


@pytest.fixture
def tag(db, user):
    return TagFactory(user=user)


@pytest.fixture
def task(db, user):
    return TaskFactory(user=user)


@pytest.fixture
def time_block(db, user):
    return TimeBlockFactory(task__user=user)


@pytest.fixture
def pomodoro_session(db, user):
    return PomodoroSessionFactory(user=user, task__user=user)


@pytest.fixture
def semester(db, user):
    return SemesterFactory(user=user)


@pytest.fixture
def discipline(db, user):
    return DisciplineFactory(semester__user=user)


@pytest.fixture
def study_block(db, user):
    return StudyBlockFactory(discipline__semester__user=user)


@pytest.fixture
def class_schedule(db, user):
    return ClassScheduleFactory(discipline__semester__user=user)


@pytest.fixture
def daily_review(db, user):
    return DailyReviewFactory(user=user)

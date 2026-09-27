import datetime
from decimal import Decimal

import pytest
from rest_framework import status

from accounts.models import UserProfile
from conftest import (
    ClassCancellationFactory,
    ClassScheduleFactory,
    DisciplineFactory,
    SemesterFactory,
    StudyBlockFactory,
    TaskFactory,
    UserFactory,
)
from stats.services import day_workload

URL = "/api/v1/stats/workload/"
MONDAY = datetime.date(2026, 3, 2)


def _discipline(user, start=datetime.date(2026, 3, 1), end=datetime.date(2026, 7, 15)):
    return DisciplineFactory(semester=SemesterFactory(user=user, start_date=start, end_date=end))


def _class(user, begins, ends, day_of_week=0, **semester):
    return ClassScheduleFactory(
        discipline=_discipline(user, **semester),
        day_of_week=day_of_week,
        start_time=datetime.time(*begins),
        end_time=datetime.time(*ends),
    )


def _task(user, minutes, day=MONDAY, **overrides):
    return TaskFactory(user=user, scheduled_date=day, estimated_minutes=minutes, **overrides)


def _study_block(user, minutes, day=MONDAY):
    return StudyBlockFactory(discipline=_discipline(user), scheduled_date=day, estimated_minutes=minutes)


def _get(client, day="2026-03-02"):
    return client.get(f"{URL}?date={day}")


@pytest.mark.django_db
class TestWorkloadEndpoint:
    def test_unauthenticated_returns_401(self, api_client):
        assert _get(api_client).status_code == status.HTTP_401_UNAUTHORIZED

    def test_missing_date_is_a_400(self, authenticated_client):
        resp = authenticated_client.get(URL)
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_malformed_date_is_a_400(self, authenticated_client):
        resp = _get(authenticated_client, day="02/03/2026")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_empty_day_has_only_the_goal(self, authenticated_client):
        resp = _get(authenticated_client)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data == {
            "date": "2026-03-02",
            "task_minutes": 0,
            "study_block_minutes": 0,
            "class_minutes": 0,
            "planned_minutes": 0,
            "goal_minutes": 720,
            "over_minutes": -720,
            "unestimated_count": 0,
        }

    def test_a_full_day_sums_tasks_study_blocks_and_classes(self, authenticated_client, user):
        _task(user, 30)
        _task(user, 45, is_completed=True)
        _study_block(user, 60)
        _class(user, (10, 0), (11, 40))
        resp = _get(authenticated_client)
        assert (resp.data["task_minutes"], resp.data["study_block_minutes"], resp.data["class_minutes"]) == (
            75,
            60,
            100,
        )
        assert (resp.data["planned_minutes"], resp.data["over_minutes"]) == (235, 235 - 720)

    def test_over_minutes_is_positive_when_the_plan_exceeds_the_goal(self, authenticated_client, user):
        _task(user, 800)
        assert _get(authenticated_client).data["over_minutes"] == 80


@pytest.mark.django_db
class TestDayWorkload:
    def test_only_the_users_own_items_count(self):
        user, other = UserFactory(), UserFactory()
        _task(other, 500)
        _study_block(other, 500)
        _class(other, (8, 0), (12, 0))
        _task(other, None)
        workload = day_workload(user, MONDAY)
        assert workload["planned_minutes"] == 0
        assert workload["unestimated_count"] == 0

    def test_a_completed_task_still_counts(self):
        user = UserFactory()
        _task(user, 25, is_completed=True)
        assert day_workload(user, MONDAY)["task_minutes"] == 25

    def test_a_task_carried_over_from_an_earlier_day_does_not_count(self):
        user = UserFactory()
        _task(user, 100, day=MONDAY - datetime.timedelta(days=1))
        assert day_workload(user, MONDAY)["task_minutes"] == 0

    def test_a_study_block_on_another_day_does_not_count(self):
        user = UserFactory()
        _study_block(user, 40)
        _study_block(user, 90, day=MONDAY + datetime.timedelta(days=1))
        assert day_workload(user, MONDAY)["study_block_minutes"] == 40

    def test_classes_from_two_schedules_on_the_weekday_are_summed(self):
        user = UserFactory()
        _class(user, (10, 0), (11, 40))
        _class(user, (14, 0), (15, 30))
        _class(user, (8, 0), (9, 0), day_of_week=1)
        assert day_workload(user, MONDAY)["class_minutes"] == 100 + 90

    def test_a_cancelled_class_does_not_count(self):
        # A cancelled class is shown struck through, not planned time (#125).
        user = UserFactory()
        ClassCancellationFactory(class_schedule=_class(user, (10, 0), (11, 40)), date=MONDAY)
        _class(user, (14, 0), (15, 30))
        assert day_workload(user, MONDAY)["class_minutes"] == 90

    def test_a_class_outside_its_semester_does_not_count(self):
        user = UserFactory()
        _class(user, (10, 0), (12, 0), start=datetime.date(2026, 1, 5), end=datetime.date(2026, 2, 27))
        assert day_workload(user, MONDAY)["class_minutes"] == 0

    def test_items_without_an_estimate_are_counted_not_summed(self):
        user = UserFactory()
        _task(user, None)
        _task(user, 20)
        _study_block(user, None)
        workload = day_workload(user, MONDAY)
        assert (workload["task_minutes"], workload["study_block_minutes"]) == (20, 0)
        assert workload["unestimated_count"] == 2

    def test_goal_is_the_profiles_work_and_study_hours(self):
        user = UserFactory()
        UserProfile.objects.filter(user=user).update(
            daily_work_goal_hours=Decimal("6.5"), daily_study_goal_hours=Decimal("2.0")
        )
        workload = day_workload(user, MONDAY)
        assert workload["goal_minutes"] == 510
        assert isinstance(workload["goal_minutes"], int)

    def test_a_user_without_a_profile_row_gets_the_default_goal(self):
        user = UserFactory()
        UserProfile.objects.filter(user=user).delete()
        assert day_workload(user, MONDAY)["goal_minutes"] == (8 + 4) * 60
        assert UserProfile.objects.filter(user=user).exists()

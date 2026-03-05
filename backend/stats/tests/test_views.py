import datetime

import pytest
from django.utils import timezone
from rest_framework import status

from conftest import PomodoroSessionFactory, TaskFactory, TimeBlockFactory


@pytest.mark.django_db
class TestDailyStatsView:
    URL = "/api/v1/stats/daily/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_empty_stats(self, authenticated_client):
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["hours_focused_today"] == 0
        assert resp.data["blocks_completed_today"] == 0
        assert resp.data["blocks_total_today"] == 0
        assert resp.data["current_streak"] == 0
        assert resp.data["weekly_work_hours"] == 0
        assert resp.data["weekly_study_hours"] == 0

    def test_hours_focused_today(self, authenticated_client, user):
        today = timezone.localdate()
        PomodoroSessionFactory(
            user=user,
            task__user=user,
            session_type="focus",
            completed=True,
            duration_minutes=60,
            started_at=timezone.now(),
        )
        PomodoroSessionFactory(
            user=user,
            task__user=user,
            session_type="focus",
            completed=True,
            duration_minutes=30,
            started_at=timezone.now(),
        )
        # Incomplete session — should not count
        PomodoroSessionFactory(
            user=user,
            task__user=user,
            session_type="focus",
            completed=False,
            duration_minutes=25,
            started_at=timezone.now(),
        )
        # Break session — should not count
        PomodoroSessionFactory(
            user=user,
            task__user=user,
            session_type="short_break",
            completed=True,
            duration_minutes=5,
            started_at=timezone.now(),
        )
        resp = authenticated_client.get(self.URL)
        assert resp.data["hours_focused_today"] == 1.5  # (60+30)/60

    def test_hours_focused_excludes_other_users(self, authenticated_client, user):
        PomodoroSessionFactory(
            session_type="focus",
            completed=True,
            duration_minutes=120,
            started_at=timezone.now(),
        )  # different user
        resp = authenticated_client.get(self.URL)
        assert resp.data["hours_focused_today"] == 0

    def test_blocks_today(self, authenticated_client, user):
        today = timezone.localdate()
        completed_task = TaskFactory(user=user, is_completed=True)
        incomplete_task = TaskFactory(user=user, is_completed=False)
        TimeBlockFactory(task=completed_task, date=today, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0))
        TimeBlockFactory(
            task=incomplete_task, date=today, start_time=datetime.time(10, 0), end_time=datetime.time(11, 0)
        )
        TimeBlockFactory(task=completed_task, date=today, start_time=datetime.time(14, 0), end_time=datetime.time(15, 0))

        resp = authenticated_client.get(self.URL)
        assert resp.data["blocks_total_today"] == 3
        assert resp.data["blocks_completed_today"] == 2

    def test_blocks_excludes_other_dates(self, authenticated_client, user):
        today = timezone.localdate()
        yesterday = today - datetime.timedelta(days=1)
        task = TaskFactory(user=user, is_completed=True)
        TimeBlockFactory(task=task, date=yesterday, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0))

        resp = authenticated_client.get(self.URL)
        assert resp.data["blocks_total_today"] == 0

    def test_current_streak(self, authenticated_client, user):
        today = timezone.localdate()
        for i in range(5):
            day = today - datetime.timedelta(days=i)
            task = TaskFactory(user=user, is_completed=True)
            TimeBlockFactory(task=task, date=day, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0))

        resp = authenticated_client.get(self.URL)
        assert resp.data["current_streak"] == 5

    def test_streak_breaks_on_gap(self, authenticated_client, user):
        today = timezone.localdate()
        # Today and yesterday have blocks, but 2 days ago does not
        for i in range(2):
            day = today - datetime.timedelta(days=i)
            task = TaskFactory(user=user, is_completed=True)
            TimeBlockFactory(task=task, date=day, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0))
        # Skip day 2, add day 3
        day3 = today - datetime.timedelta(days=3)
        task = TaskFactory(user=user, is_completed=True)
        TimeBlockFactory(task=task, date=day3, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0))

        resp = authenticated_client.get(self.URL)
        assert resp.data["current_streak"] == 2

    def test_streak_requires_completed_task(self, authenticated_client, user):
        today = timezone.localdate()
        # Block exists but task not completed
        incomplete_task = TaskFactory(user=user, is_completed=False)
        TimeBlockFactory(
            task=incomplete_task, date=today, start_time=datetime.time(9, 0), end_time=datetime.time(10, 0)
        )

        resp = authenticated_client.get(self.URL)
        assert resp.data["current_streak"] == 0

    def test_weekly_work_hours(self, authenticated_client, user):
        today = timezone.localdate()
        week_start = today - datetime.timedelta(days=today.weekday())
        task = TaskFactory(user=user, area="work")
        # 2-hour block on Monday
        TimeBlockFactory(task=task, date=week_start, start_time=datetime.time(9, 0), end_time=datetime.time(11, 0))
        # 1.5-hour block on Tuesday
        tuesday = week_start + datetime.timedelta(days=1)
        TimeBlockFactory(task=task, date=tuesday, start_time=datetime.time(14, 0), end_time=datetime.time(15, 30))

        resp = authenticated_client.get(self.URL)
        assert resp.data["weekly_work_hours"] == 3.5

    def test_weekly_study_hours_separate(self, authenticated_client, user):
        today = timezone.localdate()
        week_start = today - datetime.timedelta(days=today.weekday())
        work_task = TaskFactory(user=user, area="work")
        study_task = TaskFactory(user=user, area="study")
        TimeBlockFactory(
            task=work_task, date=week_start, start_time=datetime.time(9, 0), end_time=datetime.time(11, 0)
        )
        TimeBlockFactory(
            task=study_task, date=week_start, start_time=datetime.time(13, 0), end_time=datetime.time(15, 0)
        )

        resp = authenticated_client.get(self.URL)
        assert resp.data["weekly_work_hours"] == 2.0
        assert resp.data["weekly_study_hours"] == 2.0

    def test_response_shape(self, authenticated_client):
        resp = authenticated_client.get(self.URL)
        expected_keys = {
            "hours_focused_today",
            "blocks_completed_today",
            "blocks_total_today",
            "current_streak",
            "weekly_work_hours",
            "weekly_study_hours",
        }
        assert set(resp.data.keys()) == expected_keys

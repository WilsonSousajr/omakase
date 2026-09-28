"""today/, occurrences/ and carried-over/ with recurring series (#124, invariant 2)."""

import datetime

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from conftest import TaskFactory, UserFactory
from tasks.models import Task, TaskRecurrence

MONDAY = datetime.date(2026, 3, 2)
TODAY_URL = "/api/v1/tasks/today/"
RANGE_URL = "/api/v1/tasks/occurrences/"
CARRIED_URL = "/api/v1/tasks/carried-over/"


def series(user, title: str = "Stand-up", **rule) -> Task:
    template = TaskFactory(user=user, title=title, estimated_minutes=15, priority="high")
    values = {"freq": "weekly", "weekdays": [0, 2], "starts_on": MONDAY}
    values.update(rule)
    TaskRecurrence.objects.create(task=template, **values)
    return template


@pytest.mark.django_db
class TestTodayWithSeries:
    def test_a_virtual_item_is_task_shaped_with_a_null_id(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.get(TODAY_URL, {"date": "2026-03-02"})
        assert resp.status_code == 200
        [item] = resp.json()["results"]
        assert item["id"] is None
        assert item["series"] == str(template.pk)
        assert item["occurrence_date"] == "2026-03-02"
        assert item["scheduled_date"] == "2026-03-02"
        assert item["is_virtual"] is True
        assert item["subtasks"] == []
        assert (item["is_completed"], item["kanban_status"], item["remind_at"]) == (False, "todo", None)
        assert (item["title"], item["priority"], item["estimated_minutes"]) == ("Stand-up", "high", 15)
        assert item["recurrence"]["weekdays"] == [0, 2]

    def test_a_virtual_item_has_every_key_a_row_has(self, authenticated_client, user):
        series(user)
        TaskFactory(user=user, scheduled_date=MONDAY)
        results = authenticated_client.get(TODAY_URL, {"date": "2026-03-02"}).json()["results"]
        assert len(results) == 2
        assert set(results[0]) == set(results[1])

    def test_a_row_says_it_is_not_virtual(self, authenticated_client, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY)
        [item] = authenticated_client.get(TODAY_URL, {"date": "2026-03-02"}).json()["results"]
        assert item["id"] == str(row.pk)
        assert item["is_virtual"] is False
        assert item["occurrence_date"] == "2026-03-02"

    def test_the_template_is_hidden_from_today(self, authenticated_client, user):
        template = series(user)
        Task.objects.filter(pk=template.pk).update(scheduled_date=datetime.date(2026, 3, 3))
        assert authenticated_client.get(TODAY_URL, {"date": "2026-03-03"}).json()["results"] == []

    def test_another_users_series_is_invisible(self, authenticated_client):
        series(UserFactory())
        assert authenticated_client.get(TODAY_URL, {"date": "2026-03-02"}).json()["results"] == []

    def test_query_count_does_not_grow_with_series(self, authenticated_client, user):
        def queries_for(count: int) -> int:
            for index in range(count):
                series(user, title=f"Series {index}")
            with CaptureQueriesContext(connection) as captured:
                authenticated_client.get(TODAY_URL, {"date": "2026-03-02"})
            return len(captured)

        assert queries_for(1) == queries_for(4)


@pytest.mark.django_db
class TestOccurrencesRange:
    def test_returns_rows_and_virtual_items_over_the_range(self, authenticated_client, user):
        template = series(user)
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 3))
        resp = authenticated_client.get(RANGE_URL, {"date_from": "2026-03-02", "date_to": "2026-03-08"})
        assert resp.status_code == 200
        body = resp.json()
        assert [(item["scheduled_date"], item["is_virtual"]) for item in body] == [
            ("2026-03-02", True),
            ("2026-03-03", False),
            ("2026-03-04", True),
        ]
        assert body[0]["series"] == str(template.pk)

    def test_62_days_is_the_largest_range(self, authenticated_client, user):
        resp = authenticated_client.get(RANGE_URL, {"date_from": "2026-03-01", "date_to": "2026-05-01"})
        assert resp.status_code == 200

    def test_63_days_is_a_400_naming_the_range(self, authenticated_client, user):
        resp = authenticated_client.get(RANGE_URL, {"date_from": "2026-03-01", "date_to": "2026-05-02"})
        assert resp.status_code == 400
        detail = resp.json()["detail"]
        assert "2026-03-01" in detail and "2026-05-02" in detail and "62" in detail

    def test_a_backwards_range_is_a_400_naming_both_dates(self, authenticated_client, user):
        resp = authenticated_client.get(RANGE_URL, {"date_from": "2026-03-08", "date_to": "2026-03-02"})
        assert resp.status_code == 400
        assert "2026-03-08" in resp.json()["detail"]

    @pytest.mark.parametrize("params", [{}, {"date_from": "2026-03-02"}, {"date_to": "2026-03-02"}])
    def test_both_bounds_are_required(self, authenticated_client, params):
        assert authenticated_client.get(RANGE_URL, params).status_code == 400

    def test_another_users_items_are_invisible(self, authenticated_client):
        other = UserFactory()
        series(other)
        TaskFactory(user=other, scheduled_date=MONDAY)
        resp = authenticated_client.get(RANGE_URL, {"date_from": "2026-03-02", "date_to": "2026-03-08"})
        assert resp.json() == []

    def test_anonymous_is_401(self, api_client):
        assert api_client.get(RANGE_URL, {"date_from": "2026-03-02", "date_to": "2026-03-02"}).status_code == 401


@pytest.mark.django_db
class TestCarriedOverWithSeries:
    def test_a_lapsed_virtual_occurrence_does_not_carry_over(self, authenticated_client, user):
        series(user, freq="daily", weekdays=[])
        assert authenticated_client.get(CARRIED_URL, {"date": "2026-03-05"}).json() == []

    def test_an_unfinished_concrete_occurrence_carries_over(self, authenticated_client, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY)
        [item] = authenticated_client.get(CARRIED_URL, {"date": "2026-03-05"}).json()
        assert item["id"] == str(row.pk)
        assert item["series"] == str(template.pk)

    def test_a_skipped_occurrence_does_not_carry_over(self, authenticated_client, user):
        template = series(user)
        TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY, is_skipped=True)
        assert authenticated_client.get(CARRIED_URL, {"date": "2026-03-05"}).json() == []

    def test_the_template_does_not_carry_over(self, authenticated_client, user):
        template = series(user)
        Task.objects.filter(pk=template.pk).update(scheduled_date=MONDAY)
        assert authenticated_client.get(CARRIED_URL, {"date": "2026-03-05"}).json() == []


@pytest.mark.django_db
class TestTaskListWithSeries:
    def test_the_template_is_listed_with_its_rule(self, authenticated_client, user):
        template = series(user)
        results = authenticated_client.get("/api/v1/tasks/").json()["results"]
        [listed] = [item for item in results if item["id"] == str(template.pk)]
        assert listed["recurrence"]["freq"] == "weekly"

    def test_another_users_template_is_not_listed(self, authenticated_client):
        series(UserFactory())
        assert authenticated_client.get("/api/v1/tasks/").json()["results"] == []

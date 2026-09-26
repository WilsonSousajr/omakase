import datetime

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from conftest import SubtaskFactory, TaskFactory

DAY = datetime.date(2026, 3, 7)


@pytest.mark.django_db
class TestDaySubtasks:
    def test_today_embeds_subtasks_in_order(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=DAY)
        SubtaskFactory(task=task, title="second", order=2)
        SubtaskFactory(task=task, title="first", order=1)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert [s["title"] for s in resp.data["results"][0]["subtasks"]] == ["first", "second"]

    def test_carried_over_embeds_subtasks(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=DAY - datetime.timedelta(days=1), is_completed=False)
        SubtaskFactory(task=task)
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-07")
        assert len(resp.data[0]["subtasks"]) == 1

    def test_the_plain_list_is_unchanged(self, authenticated_client, user):
        TaskFactory(user=user)
        resp = authenticated_client.get("/api/v1/tasks/")
        assert "subtasks" not in resp.data["results"][0]

    def test_embedding_adds_no_query_per_task(self, authenticated_client, user):
        def queries_for(count: int) -> int:
            for _ in range(count):
                SubtaskFactory(task=TaskFactory(user=user, scheduled_date=DAY))
            with CaptureQueriesContext(connection) as ctx:
                authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
            return len(ctx.captured_queries)

        assert queries_for(1) == queries_for(5)

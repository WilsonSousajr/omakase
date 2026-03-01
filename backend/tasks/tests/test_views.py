import datetime
import uuid

import pytest
from rest_framework import status

from conftest import TagFactory, TaskFactory, TimeBlockFactory
from pomodoro.models import PomodoroSession
from tasks.models import Task, TimeBlock


@pytest.mark.django_db
class TestTaskViewSet:
    def test_list_tasks(self, api_client):
        TaskFactory.create_batch(3)
        resp = api_client.get("/api/v1/tasks/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 3

    def test_create_task_minimal(self, api_client):
        resp = api_client.post("/api/v1/tasks/", {"title": "New task"}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["title"] == "New task"
        assert resp.data["priority"] == "medium"
        assert resp.data["kanban_status"] == "todo"

    def test_create_task_with_tags(self, api_client):
        tag = TagFactory()
        resp = api_client.post(
            "/api/v1/tasks/",
            {"title": "Tagged task", "tag_ids": [str(tag.pk)]},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert len(resp.data["tags"]) == 1
        assert resp.data["tags"][0]["id"] == str(tag.pk)

    def test_retrieve_task(self, api_client):
        task = TaskFactory(notes="My notes")
        TimeBlockFactory(task=task)
        resp = api_client.get(f"/api/v1/tasks/{task.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["notes"] == "My notes"
        assert "time_blocks" in resp.data
        assert len(resp.data["time_blocks"]) == 1

    def test_update_task_partial(self, api_client):
        task = TaskFactory(title="Old title")
        resp = api_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"title": "New title"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["title"] == "New title"

    def test_update_completes_task(self, api_client):
        task = TaskFactory(is_completed=False)
        resp = api_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"is_completed": True},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed_at"] is not None

    def test_update_uncompletes_task(self, api_client):
        task = TaskFactory(is_completed=True)
        # Set completed_at directly since factory doesn't trigger serializer logic
        from django.utils import timezone
        Task.objects.filter(pk=task.pk).update(completed_at=timezone.now())
        resp = api_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"is_completed": False},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed_at"] is None

    def test_delete_task(self, api_client):
        task = TaskFactory()
        resp = api_client.delete(f"/api/v1/tasks/{task.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_delete_task_cascades_timeblocks(self, api_client):
        tb = TimeBlockFactory()
        task_pk = tb.task.pk
        api_client.delete(f"/api/v1/tasks/{task_pk}/")
        assert not TimeBlock.objects.filter(task_id=task_pk).exists()

    def test_delete_task_nullifies_pomodoro(self, api_client):
        task = TaskFactory()
        from conftest import PomodoroSessionFactory
        session = PomodoroSessionFactory(task=task)
        api_client.delete(f"/api/v1/tasks/{task.pk}/")
        session.refresh_from_db()
        assert session.task is None

    def test_filter_by_priority(self, api_client):
        TaskFactory(priority="high")
        TaskFactory(priority="low")
        resp = api_client.get("/api/v1/tasks/?priority=high")
        assert resp.data["count"] == 1
        assert resp.data["results"][0]["priority"] == "high"

    def test_filter_by_kanban_status(self, api_client):
        TaskFactory(kanban_status="in_progress")
        TaskFactory(kanban_status="todo")
        resp = api_client.get("/api/v1/tasks/?kanban_status=in_progress")
        assert resp.data["count"] == 1

    def test_filter_by_scheduled_date(self, api_client):
        TaskFactory(scheduled_date=datetime.date(2025, 1, 1))
        TaskFactory(scheduled_date=datetime.date(2025, 1, 2))
        resp = api_client.get("/api/v1/tasks/?scheduled_date=2025-01-01")
        assert resp.data["count"] == 1

    def test_filter_by_is_completed(self, api_client):
        TaskFactory(is_completed=True)
        TaskFactory(is_completed=False)
        resp = api_client.get("/api/v1/tasks/?is_completed=true")
        assert resp.data["count"] == 1

    def test_search_by_title(self, api_client):
        TaskFactory(title="Deploy to production")
        TaskFactory(title="Write tests")
        resp = api_client.get("/api/v1/tasks/?search=Deploy")
        assert resp.data["count"] == 1

    def test_ordering_by_created_at(self, api_client):
        TaskFactory.create_batch(3)
        resp = api_client.get("/api/v1/tasks/?ordering=-created_at")
        assert resp.status_code == status.HTTP_200_OK
        dates = [r["created_at"] for r in resp.data["results"]]
        assert dates == sorted(dates, reverse=True)

    def test_today_endpoint(self, api_client):
        from datetime import date
        TaskFactory(scheduled_date=date.today())
        TaskFactory(scheduled_date=date.today() - datetime.timedelta(days=1))
        resp = api_client.get("/api/v1/tasks/today/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 1

    def test_today_empty(self, api_client):
        TaskFactory(scheduled_date=datetime.date(2020, 1, 1))
        resp = api_client.get("/api/v1/tasks/today/")
        assert resp.data["count"] == 0

    def test_reorder_bulk_success(self, api_client):
        t1 = TaskFactory()
        t2 = TaskFactory()
        payload = [
            {"id": str(t1.pk), "kanban_order": 1, "kanban_status": "todo"},
            {"id": str(t2.pk), "kanban_order": 0, "kanban_status": "in_progress"},
        ]
        resp = api_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data == {"status": "ok"}

    def test_reorder_bulk_updates_status(self, api_client):
        task = TaskFactory(kanban_status="todo")
        payload = [{"id": str(task.pk), "kanban_order": 0, "kanban_status": "done"}]
        api_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        task.refresh_from_db()
        assert task.kanban_status == "done"

    def test_reorder_bulk_not_list(self, api_client):
        resp = api_client.patch(
            "/api/v1/tasks/reorder-bulk/", {"id": "abc"}, format="json"
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_exceeds_limit(self, api_client):
        payload = [
            {"id": str(uuid.uuid4()), "kanban_order": i, "kanban_status": "todo"}
            for i in range(101)
        ]
        resp = api_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_invalid_item(self, api_client):
        payload = [
            {"id": str(uuid.uuid4()), "kanban_order": 0, "kanban_status": "invalid"}
        ]
        resp = api_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_nonexistent_task_404(self, api_client):
        resp = api_client.get(f"/api/v1/tasks/{uuid.uuid4()}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db
class TestTagViewSet:
    def test_list_tags(self, api_client):
        TagFactory.create_batch(2)
        resp = api_client.get("/api/v1/tags/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_create_tag(self, api_client):
        resp = api_client.post(
            "/api/v1/tags/",
            {"name": "Frontend", "color": "#00ff00", "area": "work"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "Frontend"

    def test_create_tag_invalid_color(self, api_client):
        resp = api_client.post(
            "/api/v1/tags/",
            {"name": "Bad", "color": "nothex", "area": "work"},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_filter_by_area(self, api_client):
        TagFactory(area="work")
        TagFactory(area="personal")
        resp = api_client.get("/api/v1/tags/?area=work")
        assert resp.data["count"] == 1

    def test_search_by_name(self, api_client):
        TagFactory(name="Design")
        TagFactory(name="Backend")
        resp = api_client.get("/api/v1/tags/?search=Design")
        assert resp.data["count"] == 1

    def test_delete_tag(self, api_client):
        tag = TagFactory()
        resp = api_client.delete(f"/api/v1/tags/{tag.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT


@pytest.mark.django_db
class TestTimeBlockViewSet:
    def test_list_timeblocks(self, api_client):
        TimeBlockFactory.create_batch(2)
        resp = api_client.get("/api/v1/timeblocks/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_create_timeblock(self, api_client):
        task = TaskFactory()
        resp = api_client.post(
            "/api/v1/timeblocks/",
            {
                "task": str(task.pk),
                "date": "2025-01-15",
                "start_time": "09:00:00",
                "end_time": "10:00:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED

    def test_create_invalid_times(self, api_client):
        """end_time <= start_time is rejected by DB CheckConstraint."""
        from django.db.utils import IntegrityError
        task = TaskFactory()
        with pytest.raises(IntegrityError, match="timeblock_end_after_start"):
            api_client.post(
                "/api/v1/timeblocks/",
                {
                    "task": str(task.pk),
                    "date": "2025-01-15",
                    "start_time": "10:00:00",
                    "end_time": "09:00:00",
                },
                format="json",
            )

    def test_filter_by_date(self, api_client):
        TimeBlockFactory(date=datetime.date(2025, 1, 15))
        TimeBlockFactory(date=datetime.date(2025, 1, 16))
        resp = api_client.get("/api/v1/timeblocks/?date=2025-01-15")
        assert resp.data["count"] == 1

    def test_filter_by_date_range(self, api_client):
        TimeBlockFactory(date=datetime.date(2025, 1, 10))
        TimeBlockFactory(date=datetime.date(2025, 1, 20))
        TimeBlockFactory(date=datetime.date(2025, 1, 30))
        resp = api_client.get("/api/v1/timeblocks/?date_from=2025-01-10&date_to=2025-01-20")
        assert resp.data["count"] == 2

    def test_filter_by_task(self, api_client):
        tb = TimeBlockFactory()
        TimeBlockFactory()  # different task
        resp = api_client.get(f"/api/v1/timeblocks/?task={tb.task.pk}")
        assert resp.data["count"] == 1

    def test_update_timeblock(self, api_client):
        tb = TimeBlockFactory()
        resp = api_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"end_time": "11:00:00"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["end_time"] == "11:00:00"

    def test_delete_timeblock(self, api_client):
        tb = TimeBlockFactory()
        task_pk = tb.task.pk
        resp = api_client.delete(f"/api/v1/timeblocks/{tb.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT
        assert Task.objects.filter(pk=task_pk).exists()

import datetime
import uuid

import pytest
from rest_framework import status

from conftest import (
    DisciplineFactory,
    ProjectFactory,
    SubtaskFactory,
    TagFactory,
    TaskFactory,
    TimeBlockFactory,
    UserFactory,
    WorkspaceFactory,
)
from tasks.models import Subtask, Task, TimeBlock


@pytest.mark.django_db
class TestTaskViewSet:
    def test_list_tasks(self, authenticated_client, user):
        TaskFactory.create_batch(3, user=user)
        resp = authenticated_client.get("/api/v1/tasks/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 3

    def test_list_tasks_scoped_to_user(self, authenticated_client, user):
        TaskFactory.create_batch(2, user=user)
        TaskFactory.create_batch(3)  # different user
        resp = authenticated_client.get("/api/v1/tasks/")
        assert resp.data["count"] == 2

    def test_create_task_minimal(self, authenticated_client, user):
        resp = authenticated_client.post("/api/v1/tasks/", {"title": "New task"}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["title"] == "New task"
        assert resp.data["priority"] == "medium"
        assert resp.data["kanban_status"] == "todo"
        assert Task.objects.get(pk=resp.data["id"]).user == user

    def test_create_task_with_tags(self, authenticated_client, user):
        tag = TagFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "Tagged task", "tag_ids": [str(tag.pk)]},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert len(resp.data["tags"]) == 1
        assert resp.data["tags"][0]["id"] == str(tag.pk)

    def test_retrieve_task(self, authenticated_client, user):
        task = TaskFactory(notes="My notes", user=user)
        TimeBlockFactory(task=task)
        resp = authenticated_client.get(f"/api/v1/tasks/{task.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["notes"] == "My notes"
        assert "time_blocks" in resp.data
        assert len(resp.data["time_blocks"]) == 1

    def test_retrieve_other_users_task_returns_404(self, authenticated_client):
        task = TaskFactory()  # different user
        resp = authenticated_client.get(f"/api/v1/tasks/{task.pk}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_update_task_partial(self, authenticated_client, user):
        task = TaskFactory(title="Old title", user=user)
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"title": "New title"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["title"] == "New title"

    def test_update_completes_task(self, authenticated_client, user):
        task = TaskFactory(is_completed=False, user=user)
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"is_completed": True},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed_at"] is not None

    def test_update_uncompletes_task(self, authenticated_client, user):
        task = TaskFactory(is_completed=True, user=user)
        from django.utils import timezone

        Task.objects.filter(pk=task.pk).update(completed_at=timezone.now())
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"is_completed": False},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["completed_at"] is None

    def test_delete_task(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.delete(f"/api/v1/tasks/{task.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_delete_task_cascades_timeblocks(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user)
        task_pk = tb.task.pk
        authenticated_client.delete(f"/api/v1/tasks/{task_pk}/")
        assert not TimeBlock.objects.filter(task_id=task_pk).exists()

    def test_delete_task_nullifies_pomodoro(self, authenticated_client, user):
        task = TaskFactory(user=user)
        from conftest import PomodoroSessionFactory

        session = PomodoroSessionFactory(task=task, user=user)
        authenticated_client.delete(f"/api/v1/tasks/{task.pk}/")
        session.refresh_from_db()
        assert session.task is None

    def test_filter_by_priority(self, authenticated_client, user):
        TaskFactory(priority="high", user=user)
        TaskFactory(priority="low", user=user)
        resp = authenticated_client.get("/api/v1/tasks/?priority=high")
        assert resp.data["count"] == 1
        assert resp.data["results"][0]["priority"] == "high"

    def test_filter_by_kanban_status(self, authenticated_client, user):
        TaskFactory(kanban_status="in_progress", user=user)
        TaskFactory(kanban_status="todo", user=user)
        resp = authenticated_client.get("/api/v1/tasks/?kanban_status=in_progress")
        assert resp.data["count"] == 1

    def test_filter_by_scheduled_date(self, authenticated_client, user):
        TaskFactory(scheduled_date=datetime.date(2025, 1, 1), user=user)
        TaskFactory(scheduled_date=datetime.date(2025, 1, 2), user=user)
        resp = authenticated_client.get("/api/v1/tasks/?scheduled_date=2025-01-01")
        assert resp.data["count"] == 1

    def test_filter_by_is_completed(self, authenticated_client, user):
        TaskFactory(is_completed=True, user=user)
        TaskFactory(is_completed=False, user=user)
        resp = authenticated_client.get("/api/v1/tasks/?is_completed=true")
        assert resp.data["count"] == 1

    def test_search_by_title(self, authenticated_client, user):
        TaskFactory(title="Deploy to production", user=user)
        TaskFactory(title="Write tests", user=user)
        resp = authenticated_client.get("/api/v1/tasks/?search=Deploy")
        assert resp.data["count"] == 1

    def test_ordering_by_created_at(self, authenticated_client, user):
        TaskFactory.create_batch(3, user=user)
        resp = authenticated_client.get("/api/v1/tasks/?ordering=-created_at")
        assert resp.status_code == status.HTTP_200_OK
        dates = [r["created_at"] for r in resp.data["results"]]
        assert dates == sorted(dates, reverse=True)

    def test_today_endpoint_no_date_param(self, authenticated_client, user):
        from datetime import date

        TaskFactory(scheduled_date=date.today(), user=user)
        TaskFactory(scheduled_date=date.today() - datetime.timedelta(days=1), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 1

    def test_today_empty(self, authenticated_client, user):
        TaskFactory(scheduled_date=datetime.date(2020, 1, 1), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/")
        assert resp.data["count"] == 0

    def test_today_with_date_param(self, authenticated_client, user):
        TaskFactory(scheduled_date=datetime.date(2026, 3, 7), user=user)
        TaskFactory(scheduled_date=datetime.date(2026, 3, 8), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 1

    def test_today_with_date_param_empty(self, authenticated_client, user):
        TaskFactory(scheduled_date=datetime.date(2026, 3, 7), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-08")
        assert resp.data["count"] == 0

    def test_today_with_invalid_date_returns_400(self, authenticated_client, user):
        """Invalid date param must 400 — never silently fall back to server UTC.

        Falling back caused the bug where tasks vanished near midnight when
        client and server timezones disagreed (see fix 25c7db9).
        """
        from datetime import date

        TaskFactory(scheduled_date=date.today(), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=not-a-date")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_success(self, authenticated_client, user):
        t1 = TaskFactory(user=user)
        t2 = TaskFactory(user=user)
        payload = [
            {"id": str(t1.pk), "kanban_order": 1, "kanban_status": "todo"},
            {"id": str(t2.pk), "kanban_order": 0, "kanban_status": "in_progress"},
        ]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data == {"status": "ok"}

    def test_reorder_bulk_updates_status(self, authenticated_client, user):
        task = TaskFactory(kanban_status="todo", user=user)
        payload = [{"id": str(task.pk), "kanban_order": 0, "kanban_status": "done"}]
        authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        task.refresh_from_db()
        assert task.kanban_status == "done"

    def test_reorder_bulk_not_list(self, authenticated_client):
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", {"id": "abc"}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_exceeds_limit(self, authenticated_client):
        payload = [{"id": str(uuid.uuid4()), "kanban_order": i, "kanban_status": "todo"} for i in range(101)]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_invalid_item(self, authenticated_client):
        payload = [{"id": str(uuid.uuid4()), "kanban_order": 0, "kanban_status": "invalid"}]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_nonexistent_task_404(self, authenticated_client):
        resp = authenticated_client.get(f"/api/v1/tasks/{uuid.uuid4()}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_task_actual_minutes_with_time_blocks(self, authenticated_client, user):
        """Task with 2 time blocks (30min each) returns 60 actual_minutes."""
        task = TaskFactory(user=user)
        TimeBlockFactory(task=task, start_time=datetime.time(9, 0), end_time=datetime.time(9, 30))
        TimeBlockFactory(task=task, start_time=datetime.time(14, 0), end_time=datetime.time(14, 30))
        resp = authenticated_client.get("/api/v1/tasks/")
        task_data = next(t for t in resp.data["results"] if str(t["id"]) == str(task.pk))
        assert task_data["actual_minutes"] == 60

    def test_task_actual_minutes_zero_without_time_blocks(self, authenticated_client, user):
        """Task with no time blocks returns 0 actual_minutes."""
        TaskFactory(user=user)
        resp = authenticated_client.get("/api/v1/tasks/")
        assert resp.data["results"][0]["actual_minutes"] == 0

    def test_carried_over_returns_past_incomplete_tasks(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 10), is_completed=False)
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 11), is_completed=False)
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 9), is_completed=True)
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-11")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 1
        assert resp.data[0]["scheduled_date"] == "2026-03-10"

    def test_carried_over_excludes_completed(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 9), is_completed=True)
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-11")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 0

    def test_carried_over_excludes_today_and_future(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 11), is_completed=False)
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 12), is_completed=False)
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-11")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 0

    def test_carried_over_requires_date_param(self, authenticated_client, user):
        resp = authenticated_client.get("/api/v1/tasks/carried-over/")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_carried_over_user_scoped(self, authenticated_client, user):
        other_user = UserFactory()
        TaskFactory(user=other_user, scheduled_date=datetime.date(2026, 3, 9))
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-11")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 0

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/tasks/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestTagViewSet:
    def test_list_tags(self, authenticated_client, user):
        TagFactory.create_batch(2, user=user)
        resp = authenticated_client.get("/api/v1/tags/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_list_tags_scoped_to_user(self, authenticated_client, user):
        TagFactory.create_batch(2, user=user)
        TagFactory.create_batch(3)  # different user
        resp = authenticated_client.get("/api/v1/tags/")
        assert resp.data["count"] == 2

    def test_create_tag(self, authenticated_client, user):
        resp = authenticated_client.post(
            "/api/v1/tags/",
            {"name": "Frontend", "color": "#00ff00", "area": "work"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "Frontend"

    def test_create_tag_invalid_color(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/tags/",
            {"name": "Bad", "color": "nothex", "area": "work"},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_filter_by_area(self, authenticated_client, user):
        TagFactory(area="work", user=user)
        TagFactory(area="personal", user=user)
        resp = authenticated_client.get("/api/v1/tags/?area=work")
        assert resp.data["count"] == 1

    def test_search_by_name(self, authenticated_client, user):
        TagFactory(name="Design", user=user)
        TagFactory(name="Backend", user=user)
        resp = authenticated_client.get("/api/v1/tags/?search=Design")
        assert resp.data["count"] == 1

    def test_delete_tag(self, authenticated_client, user):
        tag = TagFactory(user=user)
        resp = authenticated_client.delete(f"/api/v1/tags/{tag.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/tags/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestTimeBlockViewSet:
    def test_list_timeblocks(self, authenticated_client, user):
        TimeBlockFactory.create_batch(2, task__user=user)
        resp = authenticated_client.get("/api/v1/timeblocks/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_list_timeblocks_scoped_to_user(self, authenticated_client, user):
        TimeBlockFactory.create_batch(2, task__user=user)
        TimeBlockFactory.create_batch(3)  # different user
        resp = authenticated_client.get("/api/v1/timeblocks/")
        assert resp.data["count"] == 2

    def test_create_timeblock(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
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

    def test_create_invalid_times(self, authenticated_client, user):
        """end_time <= start_time is rejected by serializer validation."""
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/timeblocks/",
            {
                "task": str(task.pk),
                "date": "2025-01-15",
                "start_time": "10:00:00",
                "end_time": "09:00:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_filter_by_date(self, authenticated_client, user):
        TimeBlockFactory(date=datetime.date(2025, 1, 15), task__user=user)
        TimeBlockFactory(date=datetime.date(2025, 1, 16), task__user=user)
        resp = authenticated_client.get("/api/v1/timeblocks/?date=2025-01-15")
        assert resp.data["count"] == 1

    def test_filter_by_date_range(self, authenticated_client, user):
        TimeBlockFactory(date=datetime.date(2025, 1, 10), task__user=user)
        TimeBlockFactory(date=datetime.date(2025, 1, 20), task__user=user)
        TimeBlockFactory(date=datetime.date(2025, 1, 30), task__user=user)
        resp = authenticated_client.get("/api/v1/timeblocks/?date_from=2025-01-10&date_to=2025-01-20")
        assert resp.data["count"] == 2

    def test_filter_by_task(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user)
        TimeBlockFactory(task__user=user)  # different task
        resp = authenticated_client.get(f"/api/v1/timeblocks/?task={tb.task.pk}")
        assert resp.data["count"] == 1

    def test_update_timeblock(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"end_time": "11:00:00"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["end_time"] == "11:00:00"

    def test_delete_timeblock(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user)
        task_pk = tb.task.pk
        resp = authenticated_client.delete(f"/api/v1/timeblocks/{tb.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT
        assert Task.objects.filter(pk=task_pk).exists()

    def test_create_timeblock_with_notes(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/timeblocks/",
            {
                "task": str(task.pk),
                "date": "2025-01-15",
                "start_time": "09:00:00",
                "end_time": "10:00:00",
                "notes": "Great focus session",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["notes"] == "Great focus session"

    def test_update_timeblock_notes(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"notes": "Updated session notes"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["notes"] == "Updated session notes"

    def test_notes_returned_in_get(self, authenticated_client, user):
        tb = TimeBlockFactory(task__user=user, notes="My session notes")
        resp = authenticated_client.get(f"/api/v1/timeblocks/{tb.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["notes"] == "My session notes"

    def test_notes_defaults_to_empty_string(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
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
        assert resp.data["notes"] == ""

    def test_patch_timeblock_session_rating(self, authenticated_client, user):
        task = TaskFactory(user=user)
        tb = TimeBlockFactory(task=task)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"session_rating": 4},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.data["session_rating"] == 4

    def test_session_rating_zero_rejected(self, authenticated_client, user):
        task = TaskFactory(user=user)
        tb = TimeBlockFactory(task=task)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"session_rating": 0},
            format="json",
        )
        assert resp.status_code == 400

    def test_session_rating_six_rejected(self, authenticated_client, user):
        task = TaskFactory(user=user)
        tb = TimeBlockFactory(task=task)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"session_rating": 6},
            format="json",
        )
        assert resp.status_code == 400

    def test_session_rating_null_allowed(self, authenticated_client, user):
        task = TaskFactory(user=user)
        tb = TimeBlockFactory(task=task)
        resp = authenticated_client.patch(
            f"/api/v1/timeblocks/{tb.pk}/",
            {"session_rating": None},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.data["session_rating"] is None

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/timeblocks/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestTaskViewEdgeCases:
    def test_create_task_with_nonexistent_tag_ids(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "Test", "tag_ids": [str(uuid.uuid4())]},
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_reorder_bulk_with_100_items(self, authenticated_client, user):
        """Boundary test: exactly 100 items should succeed."""
        tasks = [TaskFactory(kanban_order=i, user=user) for i in range(100)]
        payload = [{"id": str(t.id), "kanban_order": i, "kanban_status": "todo"} for i, t in enumerate(tasks)]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_200_OK

    def test_reorder_bulk_with_duplicate_ids(self, authenticated_client, user):
        task = TaskFactory(user=user)
        payload = [
            {"id": str(task.id), "kanban_order": 0, "kanban_status": "todo"},
            {"id": str(task.id), "kanban_order": 1, "kanban_status": "todo"},
        ]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_200_OK

    def test_reorder_bulk_nonexistent_ids_returns_400(self, authenticated_client):
        """Nonexistent task IDs must 400 — never silently no-op.

        Silent no-op masked client/server desync bugs (see fix c870d97).
        """
        missing_id = str(uuid.uuid4())
        payload = [
            {"id": missing_id, "kanban_order": 0, "kanban_status": "todo"},
        ]
        resp = authenticated_client.patch("/api/v1/tasks/reorder-bulk/", payload, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert missing_id in resp.data["detail"]


@pytest.mark.django_db
class TestTimeBlockViewEdgeCases:
    def test_create_timeblock_with_nonexistent_task(self, authenticated_client):
        resp = authenticated_client.post(
            "/api/v1/timeblocks/",
            {
                "task": str(uuid.uuid4()),
                "date": "2025-01-15",
                "start_time": "09:00:00",
                "end_time": "10:00:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_create_timeblock_end_before_start_returns_400(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/timeblocks/",
            {
                "task": str(task.id),
                "date": "2025-01-15",
                "start_time": "10:00:00",
                "end_time": "09:00:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestTaskIDORPrevention:
    """Test that users cannot assign another user's project/discipline to their tasks."""

    def test_create_task_with_other_users_project_returns_403(self, authenticated_client, user):
        other_workspace = WorkspaceFactory()  # different user
        other_project = ProjectFactory(workspace=other_workspace)
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "IDOR attempt", "project": str(other_project.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_patch_task_to_other_users_project_returns_403(self, authenticated_client, user):
        task = TaskFactory(user=user)
        other_workspace = WorkspaceFactory()
        other_project = ProjectFactory(workspace=other_workspace)
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"project": str(other_project.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_create_task_with_other_users_discipline_returns_403(self, authenticated_client, user):
        other_discipline = DisciplineFactory()  # different user's semester
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "IDOR attempt", "discipline": str(other_discipline.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_patch_task_to_other_users_discipline_returns_403(self, authenticated_client, user):
        task = TaskFactory(user=user)
        other_discipline = DisciplineFactory()
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.pk}/",
            {"discipline": str(other_discipline.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_403_FORBIDDEN

    def test_create_task_with_own_project_succeeds(self, authenticated_client, user):
        workspace = WorkspaceFactory(user=user)
        project = ProjectFactory(workspace=workspace)
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "My task", "project": str(project.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert str(resp.data["project"]) == str(project.pk)

    def test_create_task_with_own_discipline_succeeds(self, authenticated_client, user):
        discipline = DisciplineFactory(semester__user=user)
        resp = authenticated_client.post(
            "/api/v1/tasks/",
            {"title": "My task", "discipline": str(discipline.pk)},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert str(resp.data["discipline"]) == str(discipline.pk)


@pytest.mark.django_db
class TestSubtaskViewSet:
    def test_list_subtasks(self, authenticated_client, user):
        task = TaskFactory(user=user)
        SubtaskFactory(task=task, title="Sub 1")
        SubtaskFactory(task=task, title="Sub 2")
        resp = authenticated_client.get(f"/api/v1/tasks/{task.id}/subtasks/")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 2

    def test_create_subtask(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            f"/api/v1/tasks/{task.id}/subtasks/",
            {"title": "New sub"},
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["title"] == "New sub"
        assert resp.data["is_completed"] is False

    def test_update_subtask(self, authenticated_client, user):
        task = TaskFactory(user=user)
        sub = SubtaskFactory(task=task)
        resp = authenticated_client.patch(
            f"/api/v1/tasks/{task.id}/subtasks/{sub.id}/",
            {"is_completed": True},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["is_completed"] is True

    def test_delete_subtask(self, authenticated_client, user):
        task = TaskFactory(user=user)
        sub = SubtaskFactory(task=task)
        resp = authenticated_client.delete(f"/api/v1/tasks/{task.id}/subtasks/{sub.id}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT
        assert Subtask.objects.count() == 0

    def test_user_scoping(self, authenticated_client, user):
        other_user = UserFactory()
        other_task = TaskFactory(user=other_user)
        SubtaskFactory(task=other_task)
        resp = authenticated_client.get(f"/api/v1/tasks/{other_task.id}/subtasks/")
        assert resp.status_code == status.HTTP_200_OK
        assert len(resp.data) == 0

    def test_create_on_other_users_task_denied(self, authenticated_client, user):
        other_user = UserFactory()
        other_task = TaskFactory(user=other_user)
        resp = authenticated_client.post(
            f"/api/v1/tasks/{other_task.id}/subtasks/",
            {"title": "Sneaky sub"},
        )
        assert resp.status_code in (
            status.HTTP_403_FORBIDDEN,
            status.HTTP_404_NOT_FOUND,
        )

"""Materializing an occurrence and setting or ending a series' rule (#124, M8 design §2)."""

import datetime

import pytest

from conftest import ProjectFactory, SubtaskFactory, TagFactory, TaskFactory, UserFactory, WorkspaceFactory
from tasks.models import Task, TaskRecurrence

MONDAY = datetime.date(2026, 3, 2)
RULE = {"freq": "weekly", "interval": 1, "weekdays": [0, 2], "starts_on": "2026-03-02", "until": None}


def series(user, **rule) -> Task:
    template = TaskFactory(user=user, title="Stand-up", description="Daily sync", estimated_minutes=15, priority="high")
    values = {"freq": "weekly", "weekdays": [0, 2], "starts_on": MONDAY}
    values.update(rule)
    TaskRecurrence.objects.create(task=template, **values)
    return template


def occurrence_url(task: Task, day: str) -> str:
    return f"/api/v1/tasks/{task.pk}/occurrences/{day}/"


def recurrence_url(task: Task) -> str:
    return f"/api/v1/tasks/{task.pk}/recurrence/"


def templates(user) -> list[Task]:
    return list(Task.objects.filter(user=user, recurrence__isnull=False))


@pytest.mark.django_db
class TestMaterialize:
    def test_first_put_creates_the_row_from_the_template(self, authenticated_client, user):
        template = series(user)
        tag = TagFactory(user=user)
        template.tags.add(tag)
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {}, format="json")
        assert resp.status_code == 201, resp.content
        row = Task.objects.get(series=template)
        assert (row.occurrence_date, row.scheduled_date) == (datetime.date(2026, 3, 4),) * 2
        assert (row.title, row.description, row.priority, row.estimated_minutes) == (
            "Stand-up",
            "Daily sync",
            "high",
            15,
        )
        assert list(row.tags.all()) == [tag]
        body = resp.json()
        assert body["id"] == str(row.pk)
        assert body["is_virtual"] is False
        assert body["series"] == str(template.pk)
        assert body["subtasks"] == []

    def test_a_replay_returns_the_same_row(self, authenticated_client, user):
        template = series(user)
        first = authenticated_client.put(occurrence_url(template, "2026-03-04"), {}, format="json")
        second = authenticated_client.put(occurrence_url(template, "2026-03-04"), {}, format="json")
        assert second.status_code == 200
        assert first.json()["id"] == second.json()["id"]
        assert Task.objects.filter(series=template).count() == 1

    def test_the_body_is_applied_at_once(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {"is_completed": True}, format="json")
        assert resp.json()["is_completed"] is True
        assert resp.json()["kanban_status"] == "done"
        resp = authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-04"})
        [item] = resp.json()["results"]
        assert (item["is_virtual"], item["is_completed"]) == (False, True)

    def test_moving_keeps_the_occurrence_date(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(
            occurrence_url(template, "2026-03-04"), {"scheduled_date": "2026-03-05"}, format="json"
        )
        assert (resp.json()["scheduled_date"], resp.json()["occurrence_date"]) == ("2026-03-05", "2026-03-04")
        assert authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-04"}).json()["results"] == []

    def test_skipping_hides_the_occurrence(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {"is_skipped": True}, format="json")
        assert resp.json()["is_skipped"] is True
        assert authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-04"}).json()["results"] == []

    def test_a_date_off_the_rule_is_a_400_naming_it(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(occurrence_url(template, "2026-03-03"), {}, format="json")
        assert resp.status_code == 400
        assert "2026-03-03" in str(resp.json())
        assert not Task.objects.filter(series=template).exists()

    def test_a_stored_row_is_still_reachable_after_the_rule_changes(self, authenticated_client, user):
        template = series(user)
        authenticated_client.put(occurrence_url(template, "2026-03-04"), {}, format="json")
        TaskRecurrence.objects.filter(task=template).update(weekdays=[0])
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {"is_completed": True}, format="json")
        assert resp.status_code == 200

    def test_an_invalid_body_creates_nothing(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {"priority": "nope"}, format="json")
        assert resp.status_code == 400
        assert not Task.objects.filter(series=template).exists()

    def test_another_users_project_in_the_body_is_403_and_creates_nothing(self, authenticated_client, user):
        template = series(user)
        foreign = ProjectFactory(workspace=WorkspaceFactory(user=UserFactory()))
        resp = authenticated_client.put(
            occurrence_url(template, "2026-03-04"), {"project": str(foreign.pk)}, format="json"
        )
        assert resp.status_code == 403
        assert not Task.objects.filter(series=template).exists()

    def test_an_occurrence_id_reaches_its_series(self, authenticated_client, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY)
        resp = authenticated_client.put(occurrence_url(row, "2026-03-04"), {}, format="json")
        assert resp.status_code == 201
        assert resp.json()["series"] == str(template.pk)

    def test_a_task_outside_a_series_is_a_400(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.put(occurrence_url(task, "2026-03-04"), {}, format="json")
        assert resp.status_code == 400
        assert str(task.pk) in str(resp.json())

    def test_a_malformed_date_is_a_400(self, authenticated_client, user):
        resp = authenticated_client.put(occurrence_url(series(user), "2026-3-4"), {}, format="json")
        assert resp.status_code == 400

    def test_another_users_series_is_404(self, authenticated_client):
        template = series(UserFactory())
        resp = authenticated_client.put(occurrence_url(template, "2026-03-04"), {}, format="json")
        assert resp.status_code == 404
        assert not Task.objects.filter(series=template).exists()


@pytest.mark.django_db
class TestSetRecurrence:
    def test_a_plain_task_becomes_the_first_occurrence_of_a_new_series(self, authenticated_client, user):
        tag = TagFactory(user=user)
        task = TaskFactory(user=user, title="Gym", scheduled_date=MONDAY, estimated_minutes=60)
        task.tags.add(tag)
        SubtaskFactory(task=task, title="Stretch")
        resp = authenticated_client.put(recurrence_url(task), RULE, format="json")
        assert resp.status_code == 200, resp.content
        [template] = templates(user)
        task.refresh_from_db()
        assert (task.series, task.occurrence_date) == (template, MONDAY)
        assert (template.title, template.estimated_minutes, template.scheduled_date) == ("Gym", 60, None)
        assert list(template.tags.all()) == [tag]
        assert task.subtasks.count() == 1
        body = resp.json()
        assert body["id"] == str(task.pk)
        assert body["series"] == str(template.pk)
        assert body["recurrence"] == RULE

    def test_the_task_is_not_duplicated_on_its_own_day(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=MONDAY)
        authenticated_client.put(recurrence_url(task), RULE, format="json")
        [item] = authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-02"}).json()["results"]
        assert item["id"] == str(task.pk)
        [virtual] = authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-04"}).json()["results"]
        assert virtual["id"] is None

    def test_a_task_without_a_date_stands_for_starts_on(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=None)
        authenticated_client.put(recurrence_url(task), RULE, format="json")
        task.refresh_from_db()
        assert task.occurrence_date == MONDAY

    def test_a_second_put_updates_the_rule_without_a_second_template(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=MONDAY)
        authenticated_client.put(recurrence_url(task), RULE, format="json")
        resp = authenticated_client.put(recurrence_url(task), {**RULE, "weekdays": [4]}, format="json")
        assert resp.status_code == 200
        [template] = templates(user)
        assert template.recurrence.weekdays == [4]

    def test_a_put_on_the_template_updates_its_rule(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.put(
            recurrence_url(template), {**RULE, "freq": "daily", "weekdays": []}, format="json"
        )
        assert resp.status_code == 200
        template.recurrence.refresh_from_db()
        assert template.recurrence.freq == "daily"

    def test_an_invalid_rule_is_a_400_and_changes_nothing(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=MONDAY)
        resp = authenticated_client.put(recurrence_url(task), {**RULE, "interval": 0}, format="json")
        assert resp.status_code == 400
        assert templates(user) == []

    def test_another_users_task_is_404(self, authenticated_client):
        task = TaskFactory(user=UserFactory())
        assert authenticated_client.put(recurrence_url(task), RULE, format="json").status_code == 404
        assert not TaskRecurrence.objects.exists()


@pytest.mark.django_db
class TestStopRecurrence:
    def test_ends_the_series_the_day_before_the_clients_date(self, authenticated_client, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY)
        resp = authenticated_client.delete(recurrence_url(row) + "?date=2026-03-09")
        assert resp.status_code == 204
        template.recurrence.refresh_from_db()
        assert template.recurrence.until == datetime.date(2026, 3, 8)
        assert Task.objects.filter(pk=row.pk).exists()
        assert authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-09"}).json()["results"] == []
        assert authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-04"}).json()["count"] == 1

    def test_stopping_before_it_began_leaves_an_empty_series(self, authenticated_client, user):
        template = series(user)
        resp = authenticated_client.delete(recurrence_url(template) + "?date=2026-02-20")
        assert resp.status_code == 204
        template.recurrence.refresh_from_db()
        assert template.recurrence.until == datetime.date(2026, 3, 1)
        assert authenticated_client.get("/api/v1/tasks/today/", {"date": "2026-03-02"}).json()["results"] == []

    def test_a_later_stop_does_not_revive_the_series(self, authenticated_client, user):
        template = series(user)
        authenticated_client.delete(recurrence_url(template) + "?date=2026-03-09")
        authenticated_client.delete(recurrence_url(template) + "?date=2026-03-20")
        template.recurrence.refresh_from_db()
        assert template.recurrence.until == datetime.date(2026, 3, 8)

    def test_the_date_is_required(self, authenticated_client, user):
        resp = authenticated_client.delete(recurrence_url(series(user)))
        assert resp.status_code == 400
        assert "date" in resp.json()["detail"]

    def test_a_task_outside_a_series_is_a_400(self, authenticated_client, user):
        task = TaskFactory(user=user)
        assert authenticated_client.delete(recurrence_url(task) + "?date=2026-03-09").status_code == 400

    def test_another_users_series_is_404(self, authenticated_client):
        template = series(UserFactory())
        assert authenticated_client.delete(recurrence_url(template) + "?date=2026-03-09").status_code == 404
        template.recurrence.refresh_from_db()
        assert template.recurrence.until is None

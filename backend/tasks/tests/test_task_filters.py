"""The task list's filters for Projects and the Inbox (#223).

Each filter narrows a queryset that is already the caller's own, so another
user's id matches nothing: it returns an empty page, never their tasks.
"""

import datetime
import uuid

import pytest
from rest_framework import status

from conftest import DisciplineFactory, ProjectFactory, TaskFactory, UserFactory, WorkspaceFactory
from tasks.models import TaskRecurrence

TASKS = "/api/v1/tasks/"


def _titles(resp) -> set[str]:
    return {row["title"] for row in resp.data["results"]}


@pytest.mark.django_db
class TestProjectFilter:
    def test_project_returns_only_that_projects_tasks(self, authenticated_client, user):
        project = ProjectFactory(workspace=WorkspaceFactory(user=user))
        TaskFactory(user=user, project=project, title="in")
        TaskFactory(user=user, project=ProjectFactory(workspace=WorkspaceFactory(user=user)), title="other project")
        TaskFactory(user=user, title="no project")
        resp = authenticated_client.get(TASKS, {"project": str(project.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert _titles(resp) == {"in"}

    def test_foreign_project_returns_empty(self, authenticated_client, user):
        stranger = UserFactory()
        foreign = ProjectFactory(workspace=WorkspaceFactory(user=stranger))
        TaskFactory(user=stranger, project=foreign, title="theirs")
        resp = authenticated_client.get(TASKS, {"project": str(foreign.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 0

    def test_malformed_project_is_400(self, authenticated_client):
        resp = authenticated_client.get(TASKS, {"project": "not-a-uuid"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "project" in resp.data


@pytest.mark.django_db
class TestWorkspaceFilter:
    def test_workspace_returns_tasks_of_its_projects(self, authenticated_client, user):
        workspace = WorkspaceFactory(user=user)
        TaskFactory(user=user, project=ProjectFactory(workspace=workspace), title="a")
        TaskFactory(user=user, project=ProjectFactory(workspace=workspace), title="b")
        TaskFactory(user=user, project=ProjectFactory(workspace=WorkspaceFactory(user=user)), title="elsewhere")
        TaskFactory(user=user, title="no project")
        resp = authenticated_client.get(TASKS, {"workspace": str(workspace.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert _titles(resp) == {"a", "b"}

    def test_foreign_workspace_returns_empty(self, authenticated_client, user):
        stranger = UserFactory()
        foreign = WorkspaceFactory(user=stranger)
        TaskFactory(user=stranger, project=ProjectFactory(workspace=foreign), title="theirs")
        resp = authenticated_client.get(TASKS, {"workspace": str(foreign.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 0


@pytest.mark.django_db
class TestDisciplineFilter:
    def test_discipline_returns_only_its_tasks(self, authenticated_client, user):
        discipline = DisciplineFactory(semester__user=user)
        TaskFactory(user=user, discipline=discipline, title="in")
        TaskFactory(user=user, discipline=DisciplineFactory(semester__user=user), title="other")
        resp = authenticated_client.get(TASKS, {"discipline": str(discipline.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert _titles(resp) == {"in"}

    def test_foreign_discipline_returns_empty(self, authenticated_client, user):
        stranger = UserFactory()
        foreign = DisciplineFactory(semester__user=stranger)
        TaskFactory(user=stranger, discipline=foreign, title="theirs")
        resp = authenticated_client.get(TASKS, {"discipline": str(foreign.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 0

    def test_unknown_discipline_returns_empty(self, authenticated_client, user):
        TaskFactory(user=user, title="mine")
        resp = authenticated_client.get(TASKS, {"discipline": str(uuid.uuid4())})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 0


@pytest.mark.django_db
class TestUnscheduledFilter:
    def test_unscheduled_returns_tasks_without_a_date(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=None, title="inbox")
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 7), title="planned")
        resp = authenticated_client.get(TASKS, {"unscheduled": "true"})
        assert resp.status_code == status.HTTP_200_OK
        assert _titles(resp) == {"inbox"}

    def test_unscheduled_excludes_series_templates_and_skipped_rows(self, authenticated_client, user):
        # A template is a rule, not work; a skipped occurrence was declined (#124).
        template = TaskFactory(user=user, scheduled_date=None, title="template")
        TaskRecurrence.objects.create(task=template, freq="weekly", starts_on=datetime.date(2026, 3, 2))
        TaskFactory(
            user=user,
            series=template,
            occurrence_date=datetime.date(2026, 3, 2),
            scheduled_date=None,
            is_skipped=True,
            title="skipped",
        )
        TaskFactory(user=user, scheduled_date=None, title="inbox")
        resp = authenticated_client.get(TASKS, {"unscheduled": "true"})
        assert _titles(resp) == {"inbox"}

    def test_unscheduled_is_scoped_to_the_caller(self, authenticated_client, user):
        TaskFactory(user=UserFactory(), scheduled_date=None, title="theirs")
        TaskFactory(user=user, scheduled_date=None, title="mine")
        resp = authenticated_client.get(TASKS, {"unscheduled": "true"})
        assert _titles(resp) == {"mine"}

    def test_unscheduled_false_applies_no_filter(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=None, title="inbox")
        TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 7), title="planned")
        resp = authenticated_client.get(TASKS, {"unscheduled": "false"})
        assert _titles(resp) == {"inbox", "planned"}

    def test_unscheduled_combines_with_is_completed(self, authenticated_client, user):
        TaskFactory(user=user, scheduled_date=None, title="open")
        TaskFactory(user=user, scheduled_date=None, is_completed=True, kanban_status="done", title="done")
        resp = authenticated_client.get(TASKS, {"unscheduled": "true", "is_completed": "false"})
        assert _titles(resp) == {"open"}

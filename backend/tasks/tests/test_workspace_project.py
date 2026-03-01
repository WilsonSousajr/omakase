import uuid

import pytest
from rest_framework import status

from conftest import ProjectFactory, TaskFactory, UserFactory, WorkspaceFactory
from tasks.models import Project, Task, Workspace


# ── Workspace Model ──────────────────────────────────────────────────


@pytest.mark.django_db
class TestWorkspaceModel:
    def test_create_workspace(self):
        ws = WorkspaceFactory()
        assert ws.name.startswith("Workspace")
        assert ws.color == "#a3a3a3"
        assert ws.user is not None

    def test_workspace_str(self):
        ws = WorkspaceFactory(name="My Work")
        assert str(ws) == "My Work"

    def test_cascade_delete_user(self):
        ws = WorkspaceFactory()
        user = ws.user
        user.delete()
        assert not Workspace.objects.filter(pk=ws.pk).exists()


# ── Project Model ────────────────────────────────────────────────────


@pytest.mark.django_db
class TestProjectModel:
    def test_create_project(self):
        proj = ProjectFactory()
        assert proj.name.startswith("Project")
        assert proj.status == "active"
        assert proj.workspace is not None

    def test_project_str(self):
        proj = ProjectFactory(name="Backend API")
        assert str(proj) == "Backend API"

    def test_cascade_delete_workspace(self):
        proj = ProjectFactory()
        ws = proj.workspace
        ws.delete()
        assert not Project.objects.filter(pk=proj.pk).exists()

    def test_task_project_set_null(self):
        proj = ProjectFactory()
        task = TaskFactory(project=proj, user=proj.workspace.user)
        proj.delete()
        task.refresh_from_db()
        assert task.project is None


# ── Workspace ViewSet ────────────────────────────────────────────────


@pytest.mark.django_db
class TestWorkspaceViewSet:
    def test_list_workspaces(self, authenticated_client, user):
        WorkspaceFactory.create_batch(3, user=user)
        resp = authenticated_client.get("/api/v1/workspaces/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 3

    def test_list_workspaces_scoped_to_user(self, authenticated_client, user):
        WorkspaceFactory.create_batch(2, user=user)
        WorkspaceFactory.create_batch(3)  # different user
        resp = authenticated_client.get("/api/v1/workspaces/")
        assert resp.data["count"] == 2

    def test_create_workspace(self, authenticated_client, user):
        resp = authenticated_client.post(
            "/api/v1/workspaces/",
            {"name": "Engineering", "color": "#ff0000"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "Engineering"
        assert Workspace.objects.get(pk=resp.data["id"]).user == user

    def test_update_workspace(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user, name="Old Name")
        resp = authenticated_client.patch(
            f"/api/v1/workspaces/{ws.pk}/",
            {"name": "New Name"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["name"] == "New Name"

    def test_delete_workspace(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        resp = authenticated_client.delete(f"/api/v1/workspaces/{ws.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_project_count_annotation(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        ProjectFactory.create_batch(2, workspace=ws)
        resp = authenticated_client.get("/api/v1/workspaces/")
        assert resp.data["results"][0]["project_count"] == 2

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/workspaces/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# ── Project ViewSet ──────────────────────────────────────────────────


@pytest.mark.django_db
class TestProjectViewSet:
    def test_list_projects(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        ProjectFactory.create_batch(3, workspace=ws)
        resp = authenticated_client.get("/api/v1/projects/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 3

    def test_list_projects_scoped_to_user(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        ProjectFactory.create_batch(2, workspace=ws)
        ProjectFactory.create_batch(3)  # different user's workspace
        resp = authenticated_client.get("/api/v1/projects/")
        assert resp.data["count"] == 2

    def test_create_project(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        resp = authenticated_client.post(
            "/api/v1/projects/",
            {"workspace": str(ws.pk), "name": "Auth System", "color": "#00ff00"},
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "Auth System"

    def test_update_project(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        proj = ProjectFactory(workspace=ws, name="Old")
        resp = authenticated_client.patch(
            f"/api/v1/projects/{proj.pk}/",
            {"name": "New", "status": "paused"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["name"] == "New"
        assert resp.data["status"] == "paused"

    def test_delete_project(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        proj = ProjectFactory(workspace=ws)
        resp = authenticated_client.delete(f"/api/v1/projects/{proj.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_filter_by_workspace(self, authenticated_client, user):
        ws1 = WorkspaceFactory(user=user)
        ws2 = WorkspaceFactory(user=user)
        ProjectFactory.create_batch(2, workspace=ws1)
        ProjectFactory(workspace=ws2)
        resp = authenticated_client.get(f"/api/v1/projects/?workspace={ws1.pk}")
        assert resp.data["count"] == 2

    def test_filter_by_status(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        ProjectFactory(workspace=ws, status="active")
        ProjectFactory(workspace=ws, status="archived")
        resp = authenticated_client.get("/api/v1/projects/?status=active")
        assert resp.data["count"] == 1

    def test_task_count_annotation(self, authenticated_client, user):
        ws = WorkspaceFactory(user=user)
        proj = ProjectFactory(workspace=ws)
        TaskFactory.create_batch(3, project=proj, user=user)
        resp = authenticated_client.get("/api/v1/projects/")
        assert resp.data["results"][0]["task_count"] == 3

    def test_other_users_project_returns_404(self, authenticated_client):
        proj = ProjectFactory()  # different user
        resp = authenticated_client.get(f"/api/v1/projects/{proj.pk}/")
        assert resp.status_code == status.HTTP_404_NOT_FOUND

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get("/api/v1/projects/")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

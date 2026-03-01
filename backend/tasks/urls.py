from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ProjectViewSet, TagViewSet, TaskViewSet, TimeBlockViewSet, WorkspaceViewSet

router = DefaultRouter()
router.register("tasks", TaskViewSet, basename="task")
router.register("tags", TagViewSet, basename="tag")
router.register("timeblocks", TimeBlockViewSet, basename="timeblock")
router.register("workspaces", WorkspaceViewSet, basename="workspace")
router.register("projects", ProjectViewSet, basename="project")

urlpatterns = [
    path("", include(router.urls)),
]

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ProjectViewSet, SubtaskViewSet, TagViewSet, TaskViewSet, TimeBlockViewSet, WorkspaceViewSet

router = DefaultRouter()
router.register("tasks", TaskViewSet, basename="task")
router.register("tags", TagViewSet, basename="tag")
router.register("timeblocks", TimeBlockViewSet, basename="timeblock")
router.register("workspaces", WorkspaceViewSet, basename="workspace")
router.register("projects", ProjectViewSet, basename="project")

subtask_list = SubtaskViewSet.as_view({"get": "list", "post": "create"})
subtask_detail = SubtaskViewSet.as_view(
    {"get": "retrieve", "patch": "partial_update", "put": "update", "delete": "destroy"}
)

urlpatterns = [
    path("", include(router.urls)),
    path("tasks/<uuid:task_pk>/subtasks/", subtask_list, name="subtask-list"),
    path("tasks/<uuid:task_pk>/subtasks/<uuid:pk>/", subtask_detail, name="subtask-detail"),
]

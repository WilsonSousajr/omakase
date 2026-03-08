from datetime import date

from django.db import transaction
from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .constants import REORDER_BULK_MAX_ITEMS
from .models import Project, Tag, Task, TimeBlock, Workspace
from .serializers import (
    ProjectSerializer,
    TagSerializer,
    TaskListSerializer,
    TaskReorderSerializer,
    TaskSerializer,
    TimeBlockSerializer,
    WorkspaceSerializer,
)


class TaskFilter(filters.FilterSet):
    scheduled_date = filters.DateFilter()
    is_completed = filters.BooleanFilter()

    class Meta:
        model = Task
        fields = ["priority", "area", "kanban_status", "scheduled_date", "is_completed"]


class TaskViewSet(viewsets.ModelViewSet):
    filterset_class = TaskFilter
    search_fields = ["title", "description"]
    ordering_fields = ["kanban_order", "created_at", "priority", "due_date"]

    def get_queryset(self):
        return Task.objects.filter(user=self.request.user).prefetch_related("tags", "time_blocks")

    def get_serializer_class(self):
        if self.action == "list" or self.action == "today":
            return TaskListSerializer
        return TaskSerializer

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=["get"])
    def today(self, request):
        client_date = request.query_params.get("date")
        if client_date:
            try:
                target_date = date.fromisoformat(client_date)
            except ValueError:
                target_date = date.today()
        else:
            target_date = date.today()
        tasks = self.get_queryset().filter(scheduled_date=target_date)
        page = self.paginate_queryset(tasks)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["patch"], url_path="reorder-bulk")
    def reorder_bulk(self, request):
        if not isinstance(request.data, list) or len(request.data) > REORDER_BULK_MAX_ITEMS:
            return Response(
                {"detail": "Request must be a list of 100 items or fewer."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = TaskReorderSerializer(data=request.data, many=True)
        serializer.is_valid(raise_exception=True)
        task_ids = [item["id"] for item in serializer.validated_data]
        with transaction.atomic():
            tasks_by_id = {
                t.id: t for t in Task.objects.filter(id__in=task_ids, user=self.request.user).select_for_update()
            }
            for item in serializer.validated_data:
                task = tasks_by_id.get(item["id"])
                if task:
                    task.kanban_order = item["kanban_order"]
                    task.kanban_status = item["kanban_status"]
                    task.save()
        return Response({"status": "ok"})


class TagFilter(filters.FilterSet):
    class Meta:
        model = Tag
        fields = ["area"]


class TagViewSet(viewsets.ModelViewSet):
    serializer_class = TagSerializer
    filterset_class = TagFilter
    search_fields = ["name"]

    def get_queryset(self):
        return Tag.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TimeBlockFilter(filters.FilterSet):
    date_from = filters.DateFilter(field_name="date", lookup_expr="gte")
    date_to = filters.DateFilter(field_name="date", lookup_expr="lte")

    class Meta:
        model = TimeBlock
        fields = ["date", "task"]


class TimeBlockViewSet(viewsets.ModelViewSet):
    serializer_class = TimeBlockSerializer
    filterset_class = TimeBlockFilter

    def get_queryset(self):
        from django.db.models import Q

        return (
            TimeBlock.objects.filter(
                Q(task__user=self.request.user) | Q(study_block__discipline__semester__user=self.request.user)
            )
            .select_related("task", "study_block")
            .distinct()
        )

    def _validate_ownership(self, serializer):
        task = serializer.validated_data.get("task")
        study_block = serializer.validated_data.get("study_block")
        if task and task.user != self.request.user:
            raise PermissionDenied("You do not own this task.")
        if study_block and study_block.discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this study block.")

    def perform_create(self, serializer):
        self._validate_ownership(serializer)
        serializer.save()

    def perform_update(self, serializer):
        self._validate_ownership(serializer)
        serializer.save()


class WorkspaceViewSet(viewsets.ModelViewSet):
    serializer_class = WorkspaceSerializer

    def get_queryset(self):
        return (
            Workspace.objects.filter(user=self.request.user).annotate(project_count=Count("projects")).order_by("name")
        )

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ProjectFilter(filters.FilterSet):
    class Meta:
        model = Project
        fields = ["workspace", "status"]


class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class = ProjectSerializer
    filterset_class = ProjectFilter

    def get_queryset(self):
        return (
            Project.objects.filter(workspace__user=self.request.user)
            .annotate(task_count=Count("tasks"))
            .order_by("name")
        )

    def perform_create(self, serializer):
        workspace = serializer.validated_data.get("workspace")
        if workspace and workspace.user != self.request.user:
            raise PermissionDenied("You do not own this workspace.")
        serializer.save()

    def perform_update(self, serializer):
        workspace = serializer.validated_data.get("workspace")
        if workspace and workspace.user != self.request.user:
            raise PermissionDenied("You do not own this workspace.")
        serializer.save()

from datetime import date

from django.db import transaction
from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .constants import REORDER_BULK_MAX_ITEMS
from .models import Project, Subtask, Tag, Task, TimeBlock, Workspace
from .serializers import (
    ProjectSerializer,
    SubtaskSerializer,
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
        if self.action in ("list", "today", "carried_over"):
            return TaskListSerializer
        return TaskSerializer

    def _validate_ownership(self, serializer):
        project = serializer.validated_data.get("project")
        discipline = serializer.validated_data.get("discipline")
        if project and project.workspace.user != self.request.user:
            raise PermissionDenied("You do not own this project.")
        if discipline and discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this discipline.")

    def perform_create(self, serializer):
        self._validate_ownership(serializer)
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        self._validate_ownership(serializer)
        serializer.save()

    @action(detail=False, methods=["get"])
    def today(self, request):
        client_date = request.query_params.get("date")
        if client_date:
            try:
                target_date = date.fromisoformat(client_date)
            except ValueError:
                return Response(
                    {"detail": "Invalid date format."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        else:
            target_date = date.today()
        tasks = self.get_queryset().filter(scheduled_date=target_date)
        page = self.paginate_queryset(tasks)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="carried-over")
    def carried_over(self, request):
        date_str = request.query_params.get("date")
        if not date_str:
            return Response(
                {"detail": "date param required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            return Response(
                {"detail": "Invalid date format."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        tasks = self.get_queryset().filter(
            scheduled_date__lt=target_date,
            is_completed=False,
        )
        serializer = self.get_serializer(tasks, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["patch"], url_path="reorder-bulk")
    def reorder_bulk(self, request):
        from django.utils import timezone as tz

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
            tasks_to_update = []
            now = tz.now()
            for item in serializer.validated_data:
                task = tasks_by_id.get(item["id"])
                if not task:
                    continue
                old_status = task.kanban_status
                task.kanban_order = item["kanban_order"]
                task.kanban_status = item["kanban_status"]
                # Sync is_completed/completed_at when kanban_status changes
                # (replicates Task.save() logic that bulk_update bypasses)
                if old_status != task.kanban_status:
                    if task.kanban_status == "done":
                        task.is_completed = True
                        if not task.completed_at:
                            task.completed_at = now
                    elif old_status == "done":
                        task.is_completed = False
                        task.completed_at = None
                tasks_to_update.append(task)
            if tasks_to_update:
                Task.objects.bulk_update(
                    tasks_to_update,
                    ["kanban_order", "kanban_status", "is_completed", "completed_at"],
                )
        return Response({"status": "ok"})


class SubtaskViewSet(viewsets.ModelViewSet):
    serializer_class = SubtaskSerializer
    pagination_class = None

    def get_queryset(self):
        return Subtask.objects.filter(
            task_id=self.kwargs["task_pk"],
            task__user=self.request.user,
        )

    def perform_create(self, serializer):
        try:
            task = Task.objects.get(
                id=self.kwargs["task_pk"],
                user=self.request.user,
            )
        except Task.DoesNotExist:
            raise PermissionDenied("You do not own this task.")
        serializer.save(task=task)


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

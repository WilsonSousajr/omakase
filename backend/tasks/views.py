import datetime

from django.db import transaction
from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ParseError, PermissionDenied
from rest_framework.response import Response

from idempotency.mixins import IdempotentCreateMixin
from omakase.client_dates import parse_client_date

from .constants import MAX_OCCURRENCE_RANGE_DAYS, REORDER_BULK_MAX_ITEMS
from .models import Project, Subtask, Tag, Task, TimeBlock, Workspace
from .serializers import (
    ProjectSerializer,
    SubtaskSerializer,
    TagSerializer,
    TaskDayListSerializer,
    TaskListSerializer,
    TaskOccurrenceSerializer,
    TaskRecurrenceSerializer,
    TaskReorderSerializer,
    TaskSerializer,
    TimeBlockSerializer,
    WorkspaceSerializer,
    day_items_data,
)
from .services import day_items, materialize_occurrence, series_template, set_recurrence, stop_recurrence


class TaskFilter(filters.FilterSet):
    scheduled_date = filters.DateFilter()
    is_completed = filters.BooleanFilter()

    class Meta:
        model = Task
        fields = ["priority", "area", "kanban_status", "scheduled_date", "is_completed"]


def _occurrence_range(params) -> tuple[datetime.date, datetime.date]:
    """The client's date_from..date_to, both required, forward and at most 62 days (#124)."""
    start = parse_client_date(params.get("date_from"), name="date_from")
    end = parse_client_date(params.get("date_to"), name="date_to")
    days = (end - start).days + 1
    if days < 1:
        raise ParseError(
            f"date_to {end.isoformat()} is before date_from {start.isoformat()}; expected date_from <= date_to."
        )
    if days > MAX_OCCURRENCE_RANGE_DAYS:
        raise ParseError(
            f"date_from {start.isoformat()} to date_to {end.isoformat()} spans {days} days; "
            f"expected at most {MAX_OCCURRENCE_RANGE_DAYS}."
        )
    return start, end


class TaskViewSet(IdempotentCreateMixin, viewsets.ModelViewSet):
    filterset_class = TaskFilter
    search_fields = ["title", "description"]
    ordering_fields = ["kanban_order", "created_at", "priority", "due_date"]

    DAY_ACTIONS = ("today", "carried_over")

    def get_queryset(self):
        # The series rule is embedded in every task (#124); joined, not queried per task.
        queryset = (
            Task.objects.filter(user=self.request.user)
            .select_related("recurrence", "series__recurrence")
            .prefetch_related("tags", "time_blocks")
        )
        if self.action in self.DAY_ACTIONS:
            queryset = queryset.prefetch_related("subtasks")
        return queryset

    def get_serializer_class(self):
        if self.action in self.DAY_ACTIONS:
            return TaskDayListSerializer
        if self.action == "list":
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
        # The client's day, never the server's: the backend runs in UTC (#65).
        # It includes each series' computed occurrence on the day (#124).
        target_date = parse_client_date(request.query_params.get("date"))
        items = day_items(request.user, target_date, target_date)
        page = self.paginate_queryset(items)
        if page is not None:
            return self.get_paginated_response(day_items_data(page, self.get_serializer_context()))
        return Response(day_items_data(items, self.get_serializer_context()))

    @action(detail=False, methods=["get"])
    def occurrences(self, request):
        # today/ over a range, for Plan (#124); a plain list, as class-occurrences/ is.
        start, end = _occurrence_range(request.query_params)
        return Response(day_items_data(day_items(request.user, start, end), self.get_serializer_context()))

    @action(detail=True, methods=["put"], url_path=r"occurrences/(?P<day>[^/]+)")
    def occurrence(self, request, pk=None, day=None):
        # Materialize (#124): idempotent by (series, date), so the outbox
        # replays it without an Idempotency-Key. The body applies in the same
        # transaction, so a rejected body leaves no row behind.
        target = parse_client_date(day)
        template = series_template(self.get_object())
        with transaction.atomic():
            row, created = materialize_occurrence(template, target)
            serializer = TaskOccurrenceSerializer(
                row, data=request.data, partial=True, context=self.get_serializer_context()
            )
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)
        code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(serializer.data, status=code)

    @action(detail=True, methods=["put", "delete"])
    def recurrence(self, request, pk=None):
        # Set the series' rule (PUT) or end it before the client's ?date= (DELETE) (#124).
        task = self.get_object()
        if request.method == "DELETE":
            stop_recurrence(task, parse_client_date(request.query_params.get("date")))
            return Response(status=status.HTTP_204_NO_CONTENT)
        rule = TaskRecurrenceSerializer(data=request.data)
        rule.is_valid(raise_exception=True)
        task = set_recurrence(task, rule.validated_data)
        return Response(TaskDayListSerializer(task, context=self.get_serializer_context()).data)

    @action(detail=False, methods=["get"], url_path="carried-over")
    def carried_over(self, request):
        target_date = parse_client_date(request.query_params.get("date"))
        # Rows only: an untouched occurrence in the past lapses, it does not
        # pile up; templates and skipped occurrences are not work (#124).
        tasks = self.get_queryset().filter(
            scheduled_date__lt=target_date,
            is_completed=False,
            recurrence__isnull=True,
            is_skipped=False,
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
            missing_ids = [str(tid) for tid in task_ids if tid not in tasks_by_id]
            if missing_ids:
                return Response(
                    {"detail": f"Task IDs not found: {', '.join(missing_ids)}"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            tasks_to_update = []
            now = tz.now()
            for item in serializer.validated_data:
                task = tasks_by_id[item["id"]]
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
            # from None: the lookup failure is the whole story, and chaining it
            # would say whether the task exists for another user.
            raise PermissionDenied("You do not own this task.") from None
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


class TimeBlockViewSet(IdempotentCreateMixin, viewsets.ModelViewSet):
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

from datetime import date

from django.db import transaction
from django_filters import rest_framework as filters
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .constants import REORDER_BULK_MAX_ITEMS
from .models import Tag, Task, TimeBlock
from .serializers import (
    TagSerializer,
    TaskListSerializer,
    TaskReorderSerializer,
    TaskSerializer,
    TimeBlockSerializer,
)


class TaskFilter(filters.FilterSet):
    scheduled_date = filters.DateFilter()
    is_completed = filters.BooleanFilter()

    class Meta:
        model = Task
        fields = ["priority", "area", "kanban_status", "scheduled_date", "is_completed"]


class TaskViewSet(viewsets.ModelViewSet):
    queryset = Task.objects.prefetch_related("tags", "time_blocks").all()
    filterset_class = TaskFilter
    search_fields = ["title", "description"]
    ordering_fields = ["kanban_order", "created_at", "priority", "due_date"]

    def get_serializer_class(self):
        if self.action == "list" or self.action == "today":
            return TaskListSerializer
        return TaskSerializer

    @action(detail=False, methods=["get"])
    def today(self, request):
        tasks = self.get_queryset().filter(scheduled_date=date.today())
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
                t.id: t
                for t in Task.objects.filter(id__in=task_ids).select_for_update()
            }
            to_update = []
            for item in serializer.validated_data:
                task = tasks_by_id.get(item["id"])
                if task:
                    task.kanban_order = item["kanban_order"]
                    task.kanban_status = item["kanban_status"]
                    to_update.append(task)
            if to_update:
                Task.objects.bulk_update(to_update, ["kanban_order", "kanban_status"])
        return Response({"status": "ok"})


class TagFilter(filters.FilterSet):
    class Meta:
        model = Tag
        fields = ["area"]


class TagViewSet(viewsets.ModelViewSet):
    queryset = Tag.objects.all()
    serializer_class = TagSerializer
    filterset_class = TagFilter
    search_fields = ["name"]


class TimeBlockFilter(filters.FilterSet):
    date_from = filters.DateFilter(field_name="date", lookup_expr="gte")
    date_to = filters.DateFilter(field_name="date", lookup_expr="lte")

    class Meta:
        model = TimeBlock
        fields = ["date", "task"]


class TimeBlockViewSet(viewsets.ModelViewSet):
    queryset = TimeBlock.objects.select_related("task").all()
    serializer_class = TimeBlockSerializer
    filterset_class = TimeBlockFilter

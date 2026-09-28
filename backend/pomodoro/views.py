from django.db.models import QuerySet
from django_filters import rest_framework as filters
from rest_framework import mixins, viewsets
from rest_framework.exceptions import PermissionDenied

from idempotency.mixins import IdempotentCreateMixin

from .models import PomodoroSession
from .serializers import PomodoroSessionSerializer
from .services import parse_client_instant, time_block_owner


class PomodoroSessionFilter(filters.FilterSet):
    """?started_after= (inclusive) and ?started_before= (exclusive) take aware
    instants, so a client's week is exact in its own zone; ?time_block= a UUID (#199)."""

    started_after = filters.CharFilter(method="filter_started_after")
    started_before = filters.CharFilter(method="filter_started_before")
    time_block = filters.UUIDFilter(field_name="time_block")

    class Meta:
        model = PomodoroSession
        fields = ["started_after", "started_before", "time_block"]

    def filter_started_after(self, queryset: QuerySet, name: str, value: str) -> QuerySet:
        return queryset.filter(started_at__gte=parse_client_instant(value, name))

    def filter_started_before(self, queryset: QuerySet, name: str, value: str) -> QuerySet:
        return queryset.filter(started_at__lt=parse_client_instant(value, name))


class PomodoroSessionViewSet(
    IdempotentCreateMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = PomodoroSessionSerializer
    filterset_class = PomodoroSessionFilter

    def get_queryset(self):
        # id breaks started_at ties, so pages never overlap or skip (#199).
        return (
            PomodoroSession.objects.filter(user=self.request.user)
            .select_related("task", "time_block")
            .order_by("-started_at", "id")
        )

    def perform_create(self, serializer):
        self._check_ownership(serializer)
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        self._check_ownership(serializer)
        serializer.save()

    def _check_ownership(self, serializer):
        task = serializer.validated_data.get("task")
        if task and task.user != self.request.user:
            raise PermissionDenied("You do not own this task.")
        block = serializer.validated_data.get("time_block")
        if block and time_block_owner(block) != self.request.user:
            raise PermissionDenied(f"You do not own time block {block.pk}.")

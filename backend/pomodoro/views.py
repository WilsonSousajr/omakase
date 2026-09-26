from rest_framework import mixins, viewsets
from rest_framework.exceptions import PermissionDenied

from idempotency.mixins import IdempotentCreateMixin

from .models import PomodoroSession
from .serializers import PomodoroSessionSerializer
from .services import time_block_owner


class PomodoroSessionViewSet(
    IdempotentCreateMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = PomodoroSessionSerializer

    def get_queryset(self):
        return PomodoroSession.objects.filter(user=self.request.user).select_related("task", "time_block")

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

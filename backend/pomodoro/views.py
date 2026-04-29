from rest_framework import mixins, viewsets
from rest_framework.exceptions import PermissionDenied

from .models import PomodoroSession
from .serializers import PomodoroSessionSerializer


class PomodoroSessionViewSet(
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = PomodoroSessionSerializer

    def get_queryset(self):
        return PomodoroSession.objects.filter(user=self.request.user).select_related("task")

    def perform_create(self, serializer):
        task = serializer.validated_data.get("task")
        if task and task.user != self.request.user:
            raise PermissionDenied("You do not own this task.")
        serializer.save(user=self.request.user)

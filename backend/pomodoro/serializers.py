from rest_framework import serializers

from .models import PomodoroSession


class PomodoroSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PomodoroSession
        fields = [
            "id", "task", "session_type", "duration_minutes",
            "started_at", "ended_at", "completed",
        ]
        read_only_fields = ["id", "started_at"]

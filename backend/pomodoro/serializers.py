import datetime

from django.utils import timezone
from rest_framework import serializers

from .models import PomodoroSession

# How far ahead a Mac's clock may run, and how old a queued session may be:
# the refresh token lives 7 days, so the outbox cannot hold anything older.
FUTURE_SKEW = datetime.timedelta(minutes=5)
MAX_AGE = datetime.timedelta(days=8)


class PomodoroSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PomodoroSession
        fields = [
            "id",
            "task",
            "time_block",
            "session_type",
            "duration_minutes",
            "started_at",
            "ended_at",
            "completed",
        ]
        read_only_fields = ["id"]
        extra_kwargs = {"started_at": {"required": False}}

    def validate_started_at(self, value: datetime.datetime) -> datetime.datetime:
        now = timezone.now()
        if value > now + FUTURE_SKEW:
            raise serializers.ValidationError(
                f"started_at {value.isoformat()} is in the future; expected at or before {now.isoformat()}"
            )
        if value < now - MAX_AGE:
            raise serializers.ValidationError(
                f"started_at {value.isoformat()} is older than 8 days; no queued session can be"
            )
        return value

    def validate(self, data: dict) -> dict:
        started = data.get("started_at", getattr(self.instance, "started_at", None))
        ended = data.get("ended_at", getattr(self.instance, "ended_at", None))
        if started and ended and ended < started:
            raise serializers.ValidationError(
                {"ended_at": f"ended_at {ended.isoformat()} is before started_at {started.isoformat()}"}
            )
        return data

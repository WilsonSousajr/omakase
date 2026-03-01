import uuid

from django.db import models


class SessionTypeChoices(models.TextChoices):
    FOCUS = "focus", "Focus"
    SHORT_BREAK = "short_break", "Short Break"
    LONG_BREAK = "long_break", "Long Break"


class PomodoroSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task = models.ForeignKey(
        "tasks.Task", on_delete=models.SET_NULL, null=True, blank=True, related_name="pomodoro_sessions"
    )
    session_type = models.CharField(max_length=20, choices=SessionTypeChoices.choices, default=SessionTypeChoices.FOCUS)
    duration_minutes = models.PositiveIntegerField(default=25)
    started_at = models.DateTimeField(auto_now_add=True, db_index=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    completed = models.BooleanField(default=False)

    class Meta:
        ordering = ["-started_at"]

    def __str__(self):
        label = self.task.title if self.task else "No task"
        return f"{self.get_session_type_display()} — {label}"

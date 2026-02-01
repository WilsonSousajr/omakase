from django.contrib import admin

from .models import PomodoroSession


@admin.register(PomodoroSession)
class PomodoroSessionAdmin(admin.ModelAdmin):
    list_display = ["task", "session_type", "duration_minutes", "started_at", "completed"]
    list_filter = ["session_type", "completed"]

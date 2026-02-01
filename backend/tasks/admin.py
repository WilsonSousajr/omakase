from django.contrib import admin

from .models import Tag, Task, TimeBlock


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ["name", "color", "area", "created_at"]
    list_filter = ["area"]
    search_fields = ["name"]


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ["title", "priority", "area", "kanban_status", "scheduled_date", "is_completed"]
    list_filter = ["priority", "area", "kanban_status", "is_completed"]
    search_fields = ["title", "description"]
    filter_horizontal = ["tags"]


@admin.register(TimeBlock)
class TimeBlockAdmin(admin.ModelAdmin):
    list_display = ["task", "date", "start_time", "end_time"]
    list_filter = ["date"]

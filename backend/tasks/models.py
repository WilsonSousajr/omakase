import uuid

from django.core.validators import RegexValidator
from django.db import models

from .constants import DEFAULT_TAG_COLOR

hex_color_validator = RegexValidator(
    regex=r"^#[0-9a-fA-F]{6}$",
    message="Color must be a valid hex color (e.g. #ff0000)",
)


class AreaChoices(models.TextChoices):
    WORK = "work", "Work"
    PERSONAL = "personal", "Personal"
    STUDY = "study", "Study"


class PriorityChoices(models.TextChoices):
    LOW = "low", "Low"
    MEDIUM = "medium", "Medium"
    HIGH = "high", "High"
    URGENT = "urgent", "Urgent"


class KanbanStatusChoices(models.TextChoices):
    TODO = "todo", "To Do"
    IN_PROGRESS = "in_progress", "In Progress"
    DONE = "done", "Done"


class Tag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    color = models.CharField(max_length=7, default=DEFAULT_TAG_COLOR, validators=[hex_color_validator])
    area = models.CharField(max_length=20, choices=AreaChoices.choices, default=AreaChoices.WORK)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Task(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=500)
    description = models.TextField(blank=True, default="")
    notes = models.TextField(blank=True, default="")
    priority = models.CharField(
        max_length=10, choices=PriorityChoices.choices, default=PriorityChoices.MEDIUM
    )
    area = models.CharField(max_length=20, choices=AreaChoices.choices, default=AreaChoices.WORK)
    kanban_status = models.CharField(
        max_length=20, choices=KanbanStatusChoices.choices, default=KanbanStatusChoices.TODO
    )
    tags = models.ManyToManyField(Tag, blank=True, related_name="tasks")
    scheduled_date = models.DateField(null=True, blank=True)
    due_date = models.DateField(null=True, blank=True)
    estimated_minutes = models.PositiveIntegerField(null=True, blank=True)
    kanban_order = models.IntegerField(default=0)
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["kanban_order", "-created_at"]

    def __str__(self):
        return self.title


class TimeBlock(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="time_blocks")
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["date", "start_time"]
        constraints = [
            models.CheckConstraint(
                check=models.Q(end_time__gt=models.F("start_time")),
                name="timeblock_end_after_start",
            ),
        ]

    def __str__(self):
        return f"{self.task.title} — {self.date} {self.start_time}-{self.end_time}"

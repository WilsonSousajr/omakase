import datetime
import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models

from .constants import DEFAULT_TAG_COLOR, DEFAULT_WORKSPACE_COLOR

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


class RecurrenceFreqChoices(models.TextChoices):
    DAILY = "daily", "Daily"
    WEEKLY = "weekly", "Weekly"
    MONTHLY = "monthly", "Monthly"


class ProjectStatusChoices(models.TextChoices):
    ACTIVE = "active", "Active"
    PAUSED = "paused", "Paused"
    COMPLETED = "completed", "Completed"
    ARCHIVED = "archived", "Archived"


class Workspace(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="workspaces")
    name = models.CharField(max_length=200)
    color = models.CharField(max_length=7, default=DEFAULT_WORKSPACE_COLOR, validators=[hex_color_validator])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Project(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(Workspace, on_delete=models.CASCADE, related_name="projects")
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True, default="")
    color = models.CharField(max_length=7, default=DEFAULT_WORKSPACE_COLOR, validators=[hex_color_validator])
    status = models.CharField(max_length=20, choices=ProjectStatusChoices.choices, default=ProjectStatusChoices.ACTIVE)
    due_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Tag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="tags", null=True, blank=True
    )
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
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="tasks", null=True, blank=True
    )
    project = models.ForeignKey(Project, on_delete=models.SET_NULL, null=True, blank=True, related_name="tasks")
    discipline = models.ForeignKey(
        "study.Discipline", on_delete=models.SET_NULL, null=True, blank=True, related_name="tasks"
    )
    title = models.CharField(max_length=500)
    description = models.TextField(blank=True, default="")
    notes = models.TextField(blank=True, default="")
    priority = models.CharField(max_length=10, choices=PriorityChoices.choices, default=PriorityChoices.MEDIUM)
    area = models.CharField(max_length=20, choices=AreaChoices.choices, default=AreaChoices.WORK)
    kanban_status = models.CharField(
        max_length=20,
        choices=KanbanStatusChoices.choices,
        default=KanbanStatusChoices.TODO,
        db_index=True,
    )
    tags = models.ManyToManyField(Tag, blank=True, related_name="tasks")
    scheduled_date = models.DateField(null=True, blank=True, db_index=True)
    due_date = models.DateField(null=True, blank=True)
    # "Remind me at": an instant the client schedules a notification for (#127).
    remind_at = models.DateTimeField(null=True, blank=True)
    estimated_minutes = models.PositiveIntegerField(null=True, blank=True)
    kanban_order = models.IntegerField(default=0)
    is_completed = models.BooleanField(default=False, db_index=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    # A concrete occurrence of a recurring series (#124): the template it came
    # from and the rule date it stands for. scheduled_date is separate, so a
    # moved occurrence keeps its identity. Only exceptions are rows (M8 §2).
    series = models.ForeignKey("self", on_delete=models.CASCADE, null=True, blank=True, related_name="occurrences")
    occurrence_date = models.DateField(null=True, blank=True)
    is_skipped = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["kanban_order", "-created_at"]
        constraints = [
            # Two rows for one (series, date) is the duplicate clients make
            # when they create instances; the server never can (#124).
            models.UniqueConstraint(
                fields=["series", "occurrence_date"],
                condition=models.Q(series__isnull=False),
                name="task_one_row_per_series_occurrence",
            ),
            models.CheckConstraint(
                condition=models.Q(series__isnull=True, occurrence_date__isnull=True)
                | models.Q(series__isnull=False, occurrence_date__isnull=False),
                name="task_series_and_occurrence_date_together",
            ),
        ]

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        from django.utils import timezone

        # For existing tasks, get previous state to detect changes
        if self.pk:
            try:
                old = Task.objects.get(pk=self.pk)
                old_completed = old.is_completed
                old_status = old.kanban_status
            except Task.DoesNotExist:
                old_completed = self.is_completed
                old_status = self.kanban_status
        else:
            old_completed = self.is_completed
            old_status = self.kanban_status

        # Detect which field changed
        completed_changed = old_completed != self.is_completed
        status_changed = old_status != self.kanban_status

        # Sync logic with priority to most recent change
        if completed_changed:
            # is_completed was just changed (checkbox clicked)
            if self.is_completed:
                # Checked: move to done
                self.kanban_status = "done"
                if not self.completed_at:
                    self.completed_at = timezone.now()
            else:
                # Unchecked: move to todo and clear timestamp
                self.kanban_status = "todo"
                self.completed_at = None
        elif status_changed:
            # kanban_status was just changed (drag & drop)
            if self.kanban_status == "done":
                # Moved to done: check it
                self.is_completed = True
                if not self.completed_at:
                    self.completed_at = timezone.now()
            else:
                # Moved out of done: uncheck it
                self.is_completed = False
                self.completed_at = None
        elif self.is_completed and self.kanban_status != "done":
            # Ensure sync on create
            self.kanban_status = "done"
            if not self.completed_at:
                self.completed_at = timezone.now()
        elif self.kanban_status == "done" and not self.is_completed:
            # Ensure sync on create
            self.is_completed = True
            if not self.completed_at:
                self.completed_at = timezone.now()
        elif not self.is_completed and self.kanban_status != "done":
            # Both false: clear timestamp
            self.completed_at = None

        super().save(*args, **kwargs)

    @property
    def series_rule(self) -> "TaskRecurrence | None":
        """The rule of the series this task templates or belongs to, or None.

        >>> occurrence.series_rule.freq
        'weekly'
        """
        owner = self.series or self
        return getattr(owner, "recurrence", None)


class TaskRecurrence(models.Model):
    """The rule of a recurring series (#124), expanded on read and never stored as instances.

    `weekdays` (0=Mon..6=Sun) applies to weekly rules; empty means the weekday
    of `starts_on`. `until` is inclusive; `starts_on - 1` is an empty series,
    what stopping one before it began leaves.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task = models.OneToOneField(Task, on_delete=models.CASCADE, related_name="recurrence")
    freq = models.CharField(max_length=10, choices=RecurrenceFreqChoices.choices)
    interval = models.PositiveSmallIntegerField(default=1)
    weekdays = models.JSONField(default=list, blank=True)
    starts_on = models.DateField()
    until = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(interval__gte=1, interval__lte=30),
                name="taskrecurrence_interval_1_to_30",
            ),
            models.CheckConstraint(
                condition=models.Q(until__isnull=True)
                | models.Q(until__gte=models.F("starts_on") - datetime.timedelta(days=1)),
                name="taskrecurrence_until_not_before_start",
            ),
        ]

    def __str__(self):
        return f"{self.freq} every {self.interval} from {self.starts_on}"


class Subtask(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="subtasks")
    title = models.CharField(max_length=500)
    is_completed = models.BooleanField(default=False)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["order", "created_at"]

    def __str__(self):
        return self.title


class TimeBlock(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task = models.ForeignKey(Task, on_delete=models.CASCADE, null=True, blank=True, related_name="time_blocks")
    study_block = models.ForeignKey(
        "study.StudyBlock", on_delete=models.CASCADE, null=True, blank=True, related_name="time_blocks"
    )
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    notes = models.TextField(blank=True, default="")
    session_rating = models.PositiveSmallIntegerField(
        null=True, blank=True, validators=[MinValueValidator(1), MaxValueValidator(5)]
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["date", "start_time"]
        constraints = [
            models.CheckConstraint(
                check=models.Q(end_time__gt=models.F("start_time")),
                name="timeblock_end_after_start",
            ),
            models.CheckConstraint(
                check=models.Q(task__isnull=False) | models.Q(study_block__isnull=False),
                name="timeblock_has_task_or_study_block",
            ),
        ]

    def __str__(self):
        label = self.task.title if self.task else (self.study_block.title if self.study_block else "Unlinked")
        return f"{label} — {self.date} {self.start_time}-{self.end_time}"

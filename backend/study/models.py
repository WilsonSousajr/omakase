import uuid

from django.conf import settings
from django.core.validators import RegexValidator
from django.db import models

from .constants import DEFAULT_DISCIPLINE_COLOR

hex_color_validator = RegexValidator(
    regex=r"^#[0-9a-fA-F]{6}$",
    message="Color must be a valid hex color (e.g. #ff0000)",
)


class SemesterStatusChoices(models.TextChoices):
    ACTIVE = "active", "Active"
    COMPLETED = "completed", "Completed"
    ARCHIVED = "archived", "Archived"


class DisciplineStatusChoices(models.TextChoices):
    ACTIVE = "active", "Active"
    COMPLETED = "completed", "Completed"
    DROPPED = "dropped", "Dropped"


class StudyBlockTypeChoices(models.TextChoices):
    THEORY = "theory", "Theory"
    EXERCISES = "exercises", "Exercises"
    REVIEW = "review", "Review"
    ASSIGNMENT = "assignment", "Assignment"
    EXAM_PREP = "exam_prep", "Exam Prep"
    LAB = "lab", "Lab"
    READING = "reading", "Reading"


class StudyBlockStatusChoices(models.TextChoices):
    PLANNED = "planned", "Planned"
    IN_PROGRESS = "in_progress", "In Progress"
    COMPLETED = "completed", "Completed"
    SKIPPED = "skipped", "Skipped"


class ClassTypeChoices(models.TextChoices):
    LECTURE = "lecture", "Lecture"
    LAB = "lab", "Lab"
    TUTORIAL = "tutorial", "Tutorial"
    SEMINAR = "seminar", "Seminar"


class PriorityChoices(models.TextChoices):
    LOW = "low", "Low"
    MEDIUM = "medium", "Medium"
    HIGH = "high", "High"
    URGENT = "urgent", "Urgent"


class Semester(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="semesters")
    name = models.CharField(max_length=200)
    institution = models.CharField(max_length=200, blank=True, default="")
    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(
        max_length=20, choices=SemesterStatusChoices.choices, default=SemesterStatusChoices.ACTIVE
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-start_date"]
        constraints = [
            models.CheckConstraint(
                check=models.Q(end_date__gt=models.F("start_date")),
                name="semester_end_after_start",
            ),
        ]

    def __str__(self):
        return self.name


class Discipline(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name="disciplines")
    name = models.CharField(max_length=200)
    code = models.CharField(max_length=20, blank=True, default="")
    professor = models.CharField(max_length=200, blank=True, default="")
    color = models.CharField(max_length=7, default=DEFAULT_DISCIPLINE_COLOR, validators=[hex_color_validator])
    credits = models.PositiveIntegerField(null=True, blank=True)
    target_grade = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=DisciplineStatusChoices.choices, default=DisciplineStatusChoices.ACTIVE
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.code} — {self.name}" if self.code else self.name


class StudyBlock(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    discipline = models.ForeignKey(Discipline, on_delete=models.CASCADE, related_name="study_blocks")
    title = models.CharField(max_length=500)
    block_type = models.CharField(
        max_length=20, choices=StudyBlockTypeChoices.choices, default=StudyBlockTypeChoices.THEORY
    )
    priority = models.CharField(max_length=10, choices=PriorityChoices.choices, default=PriorityChoices.MEDIUM)
    status = models.CharField(
        max_length=20, choices=StudyBlockStatusChoices.choices, default=StudyBlockStatusChoices.PLANNED
    )
    notes = models.TextField(blank=True, default="")
    estimated_minutes = models.PositiveIntegerField(null=True, blank=True)
    scheduled_date = models.DateField(null=True, blank=True, db_index=True)
    due_date = models.DateField(null=True, blank=True)
    is_completed = models.BooleanField(default=False, db_index=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        from django.utils import timezone

        if self.pk:
            try:
                old = StudyBlock.objects.get(pk=self.pk)
                old_completed = old.is_completed
                old_status = old.status
            except StudyBlock.DoesNotExist:
                old_completed = self.is_completed
                old_status = self.status
        else:
            old_completed = self.is_completed
            old_status = self.status

        completed_changed = old_completed != self.is_completed
        status_changed = old_status != self.status

        if completed_changed:
            if self.is_completed:
                self.status = "completed"
                if not self.completed_at:
                    self.completed_at = timezone.now()
            else:
                self.status = "planned"
                self.completed_at = None
        elif status_changed:
            if self.status == "completed":
                self.is_completed = True
                if not self.completed_at:
                    self.completed_at = timezone.now()
            else:
                self.is_completed = False
                self.completed_at = None
        elif self.is_completed and self.status != "completed":
            self.status = "completed"
            if not self.completed_at:
                self.completed_at = timezone.now()
        elif self.status == "completed" and not self.is_completed:
            self.is_completed = True
            if not self.completed_at:
                self.completed_at = timezone.now()
        elif not self.is_completed and self.status != "completed":
            self.completed_at = None

        super().save(*args, **kwargs)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


class ClassSchedule(models.Model):
    DAY_OF_WEEK_CHOICES = [
        (0, "Monday"),
        (1, "Tuesday"),
        (2, "Wednesday"),
        (3, "Thursday"),
        (4, "Friday"),
        (5, "Saturday"),
        (6, "Sunday"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    discipline = models.ForeignKey(Discipline, on_delete=models.CASCADE, related_name="class_schedules")
    day_of_week = models.IntegerField(choices=DAY_OF_WEEK_CHOICES)
    start_time = models.TimeField()
    end_time = models.TimeField()
    class_type = models.CharField(max_length=20, choices=ClassTypeChoices.choices, default=ClassTypeChoices.LECTURE)
    location = models.CharField(max_length=300, blank=True, default="")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["day_of_week", "start_time"]
        constraints = [
            models.CheckConstraint(
                check=models.Q(end_time__gt=models.F("start_time")),
                name="class_end_after_start",
            ),
            models.CheckConstraint(
                check=models.Q(day_of_week__gte=0, day_of_week__lte=6),
                name="class_valid_day_of_week",
            ),
        ]

    def __str__(self):
        day_name = dict(self.DAY_OF_WEEK_CHOICES).get(self.day_of_week, "")
        return f"{self.discipline} — {day_name} {self.start_time:%H:%M}"

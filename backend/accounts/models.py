import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models

hex_color_validator = RegexValidator(
    regex=r"^#[0-9a-fA-F]{6}$",
    message="Color must be a valid hex color (e.g. #ff0000)",
)

DEFAULT_AVATAR_COLOR = "#a3a3a3"
BLOCK_REMINDER_MIN = 1
BLOCK_REMINDER_MAX = 120


class Profile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    avatar_color = models.CharField(
        max_length=7,
        default=DEFAULT_AVATAR_COLOR,
        validators=[hex_color_validator],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile({self.user.username})"


class UserProfile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="user_profile",
    )
    timezone = models.CharField(max_length=50, default="UTC")
    week_starts_on = models.CharField(
        max_length=10,
        choices=[("monday", "Monday"), ("sunday", "Sunday")],
        default="monday",
    )
    pomodoro_work_minutes = models.PositiveIntegerField(default=25, validators=[MaxValueValidator(480)])
    pomodoro_short_break_minutes = models.PositiveIntegerField(default=5, validators=[MaxValueValidator(480)])
    pomodoro_long_break_minutes = models.PositiveIntegerField(default=15, validators=[MaxValueValidator(480)])
    pomodoros_before_long_break = models.PositiveIntegerField(default=4, validators=[MaxValueValidator(10)])
    daily_work_goal_hours = models.DecimalField(
        max_digits=4, decimal_places=1, default=8.0, validators=[MaxValueValidator(24)]
    )
    daily_study_goal_hours = models.DecimalField(
        max_digits=4, decimal_places=1, default=4.0, validators=[MaxValueValidator(24)]
    )
    # Reminders are defined here and scheduled by each client (#127, M3.6 spec).
    # Minutes before every time block; null turns the heads-up off.
    block_reminder_minutes = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        default=5,
        validators=[MinValueValidator(BLOCK_REMINDER_MIN), MaxValueValidator(BLOCK_REMINDER_MAX)],
    )
    # A time of day in the user's local time; null means no shutdown reminder.
    shutdown_reminder_time = models.TimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(block_reminder_minutes__isnull=True)
                | models.Q(block_reminder_minutes__range=(BLOCK_REMINDER_MIN, BLOCK_REMINDER_MAX)),
                name="block_reminder_minutes_1_to_120_or_null",
            ),
        ]

    def __str__(self):
        return f"UserProfile for {self.user.username}"

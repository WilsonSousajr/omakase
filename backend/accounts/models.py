import uuid

from django.conf import settings
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver


class UserProfile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    timezone = models.CharField(max_length=50, default="UTC")
    week_starts_on = models.CharField(
        max_length=10,
        choices=[("monday", "Monday"), ("sunday", "Sunday")],
        default="monday",
    )
    pomodoro_work_minutes = models.PositiveIntegerField(default=25)
    pomodoro_short_break_minutes = models.PositiveIntegerField(default=5)
    pomodoro_long_break_minutes = models.PositiveIntegerField(default=15)
    pomodoros_before_long_break = models.PositiveIntegerField(default=4)
    daily_work_goal_hours = models.DecimalField(max_digits=4, decimal_places=1, default=8.0)
    daily_study_goal_hours = models.DecimalField(max_digits=4, decimal_places=1, default=4.0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile for {self.user.username}"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance)

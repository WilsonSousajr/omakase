import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class DailyReview(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="daily_reviews",
    )
    date = models.DateField()
    productivity_rating = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    win_of_the_day = models.TextField(blank=True, default="")
    # How the day felt, 1 (drained) to 3 (energised): the only source for
    # IDEA §13's energy mapping (#130).
    energy = models.PositiveSmallIntegerField(null=True, blank=True)
    is_shutdown = models.BooleanField(default=False)
    shutdown_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "date")
        ordering = ["-date"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(energy__isnull=True) | models.Q(energy__gte=1, energy__lte=3),
                name="dailyreview_energy_1_to_3",
            )
        ]

    def __str__(self):
        return f"{self.user.username} — {self.date}"

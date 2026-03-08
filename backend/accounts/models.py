import uuid

from django.conf import settings
from django.core.validators import RegexValidator
from django.db import models

hex_color_validator = RegexValidator(
    regex=r"^#[0-9a-fA-F]{6}$",
    message="Color must be a valid hex color (e.g. #ff0000)",
)

DEFAULT_AVATAR_COLOR = "#a3a3a3"


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

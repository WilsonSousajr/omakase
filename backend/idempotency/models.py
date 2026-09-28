"""A stored response per (user, Idempotency-Key) (#77)."""

from django.conf import settings
from django.core.serializers.json import DjangoJSONEncoder
from django.db import models


class IdempotencyRecord(models.Model):
    """The first response to a keyed create, replayed for 7 days."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    key = models.CharField(max_length=64)
    method = models.CharField(max_length=10)
    path = models.CharField(max_length=255)
    status_code = models.PositiveSmallIntegerField()
    response_body = models.JSONField(encoder=DjangoJSONEncoder, null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "key"], name="idempotency_unique_user_key")]

    def __str__(self) -> str:
        return f"{self.method} {self.path} [{self.key}]"

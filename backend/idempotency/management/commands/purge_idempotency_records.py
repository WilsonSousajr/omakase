"""Delete idempotency records past their 7-day life (#77). Run daily."""

from django.core.management.base import BaseCommand
from django.utils import timezone

from idempotency.models import IdempotencyRecord
from idempotency.services import RECORD_TTL


class Command(BaseCommand):
    help = "Delete Idempotency-Key records older than 7 days."

    def handle(self, *args: object, **options: object) -> None:
        cutoff = timezone.now() - RECORD_TTL
        deleted, _ = IdempotencyRecord.objects.filter(created_at__lt=cutoff).delete()
        self.stdout.write(f"deleted {deleted} idempotency record(s) older than {cutoff:%Y-%m-%d %H:%M} UTC")

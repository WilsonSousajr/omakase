import datetime
import uuid

import pytest
from django.core.management import call_command
from django.utils import timezone

from idempotency.models import IdempotencyRecord


@pytest.mark.django_db
def test_purge_deletes_only_records_older_than_seven_days(user):
    fresh = IdempotencyRecord.objects.create(
        user=user, key=str(uuid.uuid4()), method="POST", path="/api/v1/tasks/", status_code=201, response_body={}
    )
    old = IdempotencyRecord.objects.create(
        user=user, key=str(uuid.uuid4()), method="POST", path="/api/v1/tasks/", status_code=201, response_body={}
    )
    IdempotencyRecord.objects.filter(pk=old.pk).update(created_at=timezone.now() - datetime.timedelta(days=8))
    call_command("purge_idempotency_records")
    assert list(IdempotencyRecord.objects.values_list("pk", flat=True)) == [fresh.pk]

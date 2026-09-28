"""Run a keyed create once per (user, key); replay it afterwards (#77).

The Mac client's outbox cannot tell "the server never got it" from "the
server did it and the reply was lost", so it retries with the same key.
Usage, from IdempotentCreateMixin::

    return run_once(request.user, key, request.method, request.path, perform)
"""

import re
from collections.abc import Callable
from datetime import timedelta

from django.contrib.auth.base_user import AbstractBaseUser
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import APIException, ParseError
from rest_framework.request import Request
from rest_framework.response import Response

from idempotency.models import IdempotencyRecord

HEADER = "Idempotency-Key"
RECORD_TTL = timedelta(days=7)
_KEY_SHAPE = re.compile(r"[A-Za-z0-9-]{1,64}")


def read_key(request: Request) -> str | None:
    """The request's key, None if absent, or a 400 naming the allowed shape."""
    if HEADER not in request.headers:
        return None
    key = request.headers[HEADER]
    if not _KEY_SHAPE.fullmatch(key):
        raise ParseError(f"{HEADER} {key!r} must be 1-64 characters of A-Z, a-z, 0-9 and '-'.")
    return key


def run_once(user: AbstractBaseUser, key: str, method: str, path: str, perform: Callable[[], Response]) -> Response:
    """Perform once and store the result, or replay what was stored."""
    # One transaction for claim, perform and store: a concurrent request with
    # the same key blocks on the unique index until this commits, then
    # replays it. Nothing half-done is ever visible.
    with transaction.atomic():
        _forget_expired(user, key)
        record, created = IdempotencyRecord.objects.get_or_create(
            user=user, key=key, defaults={"method": method, "path": path, "status_code": 0}
        )
        if not created:
            return _replay(record, method, path)
        response = _perform_as_response(perform)
        _store(record, response)
        return response


def _perform_as_response(perform: Callable[[], Response]) -> Response:
    # A serializer's ValidationError is raised, not returned. Left to
    # propagate, it would roll the claim back and the 400 would never be
    # stored, so a retry would re-run it. Shaped as DRF's own handler shapes it.
    try:
        return perform()
    except APIException as error:
        body = error.detail if isinstance(error.detail, dict | list) else {"detail": error.detail}
        return Response(body, status=error.status_code)


def _forget_expired(user: AbstractBaseUser, key: str) -> None:
    cutoff = timezone.now() - RECORD_TTL
    IdempotencyRecord.objects.filter(user=user, key=key, created_at__lt=cutoff).delete()


def _replay(record: IdempotencyRecord, method: str, path: str) -> Response:
    if (record.method, record.path) != (method, path):
        detail = f"{HEADER} {record.key!r} was first used for {record.method} {record.path}, not {method} {path}."
        return Response({"detail": detail}, status=422)
    return Response(record.response_body, status=record.status_code, headers={"Idempotent-Replayed": "true"})


def _store(record: IdempotencyRecord, response: Response) -> None:
    # A 5xx is not an answer to replay: roll the claim back so a retry acts.
    if response.status_code >= 500:
        transaction.set_rollback(True)
        return
    record.status_code = response.status_code
    record.response_body = response.data
    record.save(update_fields=["status_code", "response_body"])

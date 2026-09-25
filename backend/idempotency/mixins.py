"""Opt a ViewSet's create() into Idempotency-Key (#77).

class TaskViewSet(IdempotentCreateMixin, viewsets.ModelViewSet): ...
"""

from rest_framework.request import Request
from rest_framework.response import Response

from idempotency.services import read_key, run_once


class IdempotentCreateMixin:
    """create() runs once per key; a request without the header is unchanged."""

    def create(self, request: Request, *args: object, **kwargs: object) -> Response:
        key = read_key(request)
        parent_create = super().create
        if key is None:
            return parent_create(request, *args, **kwargs)
        return run_once(
            request.user, key, request.method, request.path, lambda: parent_create(request, *args, **kwargs)
        )

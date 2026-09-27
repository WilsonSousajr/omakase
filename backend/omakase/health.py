"""The health check Coolify calls (#243): does the database answer?

AllowAny, argued in #243: it returns one word and no data, no user and no
version, and without it the proxy can't tell a dead container from a live
one.
"""

from typing import Any

from django.db import DatabaseError, connection
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response


def database_answers(conn: Any = connection) -> bool:
    """True when ``SELECT 1`` runs. Usage: ``database_answers()``."""
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
    except DatabaseError:
        return False
    return True


@api_view(["GET"])
@authentication_classes([])
@permission_classes([AllowAny])
def health(request: Request) -> Response:
    """200 ``{"status": "ok"}`` when the database answers, 503 otherwise."""
    if database_answers():
        return Response({"status": "ok"})
    return Response({"status": "unavailable"}, status=503)

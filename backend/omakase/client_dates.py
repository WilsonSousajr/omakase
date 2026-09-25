"""The one parser for a client's ?date= (#69).

AGENTS.md invariant 2 - "today" is the client's day - had seven enforcement
points written by hand with three different messages, and #65 was one of
them drifting. Every view that reads a day from a query param calls this.

Usage::

    target = parse_client_date(request.query_params.get("date"))
"""

import datetime
import re

from rest_framework.exceptions import ParseError

# Stricter than date.fromisoformat, which in 3.12 also accepts 20260307 and
# 2026-W10-1. The wire format is exactly YYYY-MM-DD.
_CALENDAR_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")


def parse_client_date(raw: str | None, name: str = "date") -> datetime.date:
    """Parse a client-supplied day or raise a 400 naming the param and value."""
    if not raw:
        raise ParseError(f"{name} param required (YYYY-MM-DD).")
    if not _CALENDAR_DATE.fullmatch(raw):
        raise ParseError(f"{name} {raw!r} is not YYYY-MM-DD.")
    try:
        return datetime.date.fromisoformat(raw)
    except ValueError:
        raise ParseError(f"{name} {raw!r} is not YYYY-MM-DD (no such calendar date).") from None

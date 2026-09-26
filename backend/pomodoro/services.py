"""Ownership rules for sessions, reached through the hierarchy without
importing another app (the independence contract)."""

import datetime

from rest_framework.exceptions import ParseError


def time_block_owner(block):
    """The user a time block belongs to: its task's, or its study block's.

    >>> time_block_owner(block) == request.user
    """
    if block.task_id:
        return block.task.user
    return block.study_block.discipline.semester.user


# The shape a bound must have, quoted in the 400 so a client can fix it.
INSTANT_EXAMPLE = "2026-09-26T10:00:00-03:00"


def parse_client_instant(raw: str, name: str) -> datetime.datetime:
    """An aware instant from a query param, or a 400 naming it (#199).

    A naive value would be read in the server's UTC, not the client's zone,
    which is invariant 2's trap for instants instead of days.

    >>> parse_client_instant("2026-09-26T10:00:00-03:00", "started_after")
    """
    try:
        parsed = datetime.datetime.fromisoformat(raw)
    except ValueError:
        parsed = None
    if parsed is None or parsed.tzinfo is None:
        raise ParseError(f"{name} {raw!r} is not an ISO-8601 instant with an offset ({INSTANT_EXAMPLE}).")
    return parsed

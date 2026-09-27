"""Task computations that views and other apps call, not reimplement.

Recurring tasks (#124, M8 design §2) follow the rule the class timetable
does: a series is a rule expanded on read for the client's date range, and
only exceptions are rows. Clients never create instances.
"""

import datetime
from collections.abc import Callable, Iterator

from .models import RecurrenceFreqChoices, TaskRecurrence


def _days(first: datetime.date, last: datetime.date) -> Iterator[datetime.date]:
    current = first
    while current <= last:
        yield current
        current += datetime.timedelta(days=1)


def _monday(day: datetime.date) -> datetime.date:
    return day - datetime.timedelta(days=day.weekday())


def _daily_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    return (day - rule.starts_on).days % rule.interval == 0


def _weekly_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    # Weeks are counted Monday to Monday from the week of starts_on, so an
    # interval of 2 keeps a Monday/Wednesday rule on the same weeks.
    weekdays = rule.weekdays or [rule.starts_on.weekday()]
    weeks = (_monday(day) - _monday(rule.starts_on)).days // 7
    return day.weekday() in weekdays and weeks % rule.interval == 0


def _monthly_matches(rule: TaskRecurrence, day: datetime.date) -> bool:
    # A month without the day (the 31st, Feb 29) is skipped, as RFC 5545 does.
    months = (day.year - rule.starts_on.year) * 12 + day.month - rule.starts_on.month
    return day.day == rule.starts_on.day and months % rule.interval == 0


_MATCHERS: dict[str, Callable[[TaskRecurrence, datetime.date], bool]] = {
    RecurrenceFreqChoices.DAILY: _daily_matches,
    RecurrenceFreqChoices.WEEKLY: _weekly_matches,
    RecurrenceFreqChoices.MONTHLY: _monthly_matches,
}


def _bounds(rule: TaskRecurrence, start: datetime.date, end: datetime.date) -> tuple[datetime.date, datetime.date]:
    """`start`..`end` clipped to the rule's own starts_on..until."""
    last = end if rule.until is None else min(end, rule.until)
    return max(start, rule.starts_on), last


def occurs_on(rule: TaskRecurrence, day: datetime.date) -> bool:
    """Whether `day` is one of the rule's dates: inside starts_on..until and on its pattern.

    >>> occurs_on(rule, datetime.date(2026, 3, 4))
    True
    """
    first, last = _bounds(rule, day, day)
    return first <= last and _MATCHERS[rule.freq](rule, day)


def occurrence_dates(rule: TaskRecurrence, start: datetime.date, end: datetime.date) -> list[datetime.date]:
    """The rule's dates in `start`..`end` (inclusive), in order.

    >>> occurrence_dates(rule, datetime.date(2026, 3, 2), datetime.date(2026, 3, 8))
    [datetime.date(2026, 3, 2), datetime.date(2026, 3, 4)]
    """
    first, last = _bounds(rule, start, end)
    matches = _MATCHERS[rule.freq]
    return [day for day in _days(first, last) if matches(rule, day)]

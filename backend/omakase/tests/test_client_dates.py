"""The one parser for a client's ?date= (#69)."""

import datetime

import pytest
from rest_framework.exceptions import ParseError

from omakase.client_dates import parse_client_date


def test_parses_iso_calendar_date():
    assert parse_client_date("2026-03-07") == datetime.date(2026, 3, 7)


@pytest.mark.parametrize("raw", [None, ""])
def test_missing_date_names_the_param(raw):
    with pytest.raises(ParseError, match="date_from param required"):
        parse_client_date(raw, name="date_from")


def test_malformed_date_quotes_the_value_and_the_shape():
    with pytest.raises(ParseError, match=r"date 'not-a-date' is not YYYY-MM-DD"):
        parse_client_date("not-a-date")


@pytest.mark.parametrize("raw", ["20260307", "2026-W10-1", "2026-03-07T00:00", " 2026-03-07"])
def test_rejects_forms_fromisoformat_accepts(raw):
    # Python 3.12's fromisoformat accepts the basic and week forms; the API
    # contract is YYYY-MM-DD only, so a client sending anything else is a bug
    # to surface, not a date to guess at.
    with pytest.raises(ParseError):
        parse_client_date(raw)


def test_rejects_an_impossible_calendar_date():
    with pytest.raises(ParseError, match="2026-02-30"):
        parse_client_date("2026-02-30")

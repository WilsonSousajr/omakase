"""Expanding a series' rule into dates, a pure function (#124, M8 design §2)."""

import datetime

from tasks.models import TaskRecurrence
from tasks.services import occurrence_dates, occurs_on

d = datetime.date


def _rule(freq: str, starts_on: datetime.date, **overrides) -> TaskRecurrence:
    values = {"freq": freq, "interval": 1, "weekdays": [], "starts_on": starts_on, "until": None}
    values.update(overrides)
    return TaskRecurrence(**values)


class TestDaily:
    def test_every_day_in_range(self):
        rule = _rule("daily", d(2026, 3, 2))
        assert occurrence_dates(rule, d(2026, 3, 2), d(2026, 3, 4)) == [d(2026, 3, 2), d(2026, 3, 3), d(2026, 3, 4)]

    def test_interval_2_counts_from_starts_on_not_from_the_range(self):
        rule = _rule("daily", d(2026, 3, 2), interval=2)
        assert occurrence_dates(rule, d(2026, 3, 3), d(2026, 3, 8)) == [d(2026, 3, 4), d(2026, 3, 6), d(2026, 3, 8)]

    def test_nothing_before_starts_on(self):
        rule = _rule("daily", d(2026, 3, 5))
        assert occurrence_dates(rule, d(2026, 3, 1), d(2026, 3, 6)) == [d(2026, 3, 5), d(2026, 3, 6)]

    def test_until_is_inclusive(self):
        rule = _rule("daily", d(2026, 3, 2), until=d(2026, 3, 3))
        assert occurrence_dates(rule, d(2026, 3, 1), d(2026, 3, 9)) == [d(2026, 3, 2), d(2026, 3, 3)]

    def test_crosses_leap_day(self):
        rule = _rule("daily", d(2028, 2, 28))
        assert occurrence_dates(rule, d(2028, 2, 28), d(2028, 3, 1)) == [d(2028, 2, 28), d(2028, 2, 29), d(2028, 3, 1)]

    def test_empty_series_stopped_before_it_began(self):
        rule = _rule("daily", d(2026, 3, 2), until=d(2026, 3, 1))
        assert occurrence_dates(rule, d(2026, 3, 1), d(2026, 3, 9)) == []

    def test_range_backwards_is_empty(self):
        rule = _rule("daily", d(2026, 3, 2))
        assert occurrence_dates(rule, d(2026, 3, 9), d(2026, 3, 2)) == []


class TestWeekly:
    def test_empty_weekdays_means_the_weekday_of_starts_on(self):
        rule = _rule("weekly", d(2026, 3, 4))  # a Wednesday
        assert occurrence_dates(rule, d(2026, 3, 1), d(2026, 3, 18)) == [d(2026, 3, 4), d(2026, 3, 11), d(2026, 3, 18)]

    def test_several_weekdays(self):
        rule = _rule("weekly", d(2026, 3, 2), weekdays=[0, 2, 4])
        assert occurrence_dates(rule, d(2026, 3, 2), d(2026, 3, 9)) == [
            d(2026, 3, 2),
            d(2026, 3, 4),
            d(2026, 3, 6),
            d(2026, 3, 9),
        ]

    def test_interval_2_counts_weeks_from_the_week_of_starts_on(self):
        # starts_on is a Wednesday, so its Monday (3-02) is in week 0 and is
        # before the rule starts; 3-16 and 3-18 are week 2.
        rule = _rule("weekly", d(2026, 3, 4), interval=2, weekdays=[0, 2])
        assert occurrence_dates(rule, d(2026, 3, 1), d(2026, 3, 22)) == [d(2026, 3, 4), d(2026, 3, 16), d(2026, 3, 18)]

    def test_across_a_year_boundary(self):
        rule = _rule("weekly", d(2026, 12, 21), interval=2)  # a Monday
        assert occurrence_dates(rule, d(2026, 12, 21), d(2027, 1, 18)) == [
            d(2026, 12, 21),
            d(2027, 1, 4),
            d(2027, 1, 18),
        ]


class TestMonthly:
    def test_on_the_day_of_starts_on(self):
        rule = _rule("monthly", d(2026, 1, 15))
        assert occurrence_dates(rule, d(2026, 1, 1), d(2026, 3, 31)) == [d(2026, 1, 15), d(2026, 2, 15), d(2026, 3, 15)]

    def test_the_31st_skips_months_without_one(self):
        rule = _rule("monthly", d(2026, 1, 31))
        assert occurrence_dates(rule, d(2026, 1, 1), d(2026, 5, 31)) == [d(2026, 1, 31), d(2026, 3, 31), d(2026, 5, 31)]

    def test_the_29th_lands_on_feb_29_only_in_a_leap_year(self):
        rule = _rule("monthly", d(2027, 1, 29))
        dates = occurrence_dates(rule, d(2027, 1, 1), d(2028, 3, 31))
        assert d(2027, 2, 28) not in dates
        assert d(2028, 2, 29) in dates
        assert len(dates) == 14

    def test_interval_2_counts_months_from_starts_on(self):
        rule = _rule("monthly", d(2026, 11, 5), interval=2)
        assert occurrence_dates(rule, d(2026, 11, 1), d(2027, 3, 31)) == [d(2026, 11, 5), d(2027, 1, 5), d(2027, 3, 5)]

    def test_until_cuts_the_series(self):
        rule = _rule("monthly", d(2026, 1, 10), until=d(2026, 2, 9))
        assert occurrence_dates(rule, d(2026, 1, 1), d(2026, 12, 31)) == [d(2026, 1, 10)]


class TestOccursOn:
    def test_a_rule_date(self):
        assert occurs_on(_rule("weekly", d(2026, 3, 2), weekdays=[0, 2]), d(2026, 3, 4))

    def test_not_a_rule_date(self):
        assert not occurs_on(_rule("weekly", d(2026, 3, 2), weekdays=[0, 2]), d(2026, 3, 5))

    def test_after_until(self):
        assert not occurs_on(_rule("daily", d(2026, 3, 2), until=d(2026, 3, 3)), d(2026, 3, 4))

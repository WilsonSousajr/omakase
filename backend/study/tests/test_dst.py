"""Class occurrences across a daylight-saving change (#132, from M7's R3).

MyStudyLife and Power Planner users report class times shifting by an hour
after a clock change (docs/research/issues-mystudylife.md). Omakase stores a
class as a weekday plus naive local `TimeField`s, and expands it with `date`
arithmetic only, so no instant or UTC offset is ever computed and there is
nothing for a DST rule to shift. These tests turn that "should be immune"
into a checked fact, and guard the next change to the expansion (M8).

The transitions are Europe/London's in 2026: clocks go forward at 01:00 on
Sunday 29 March and back at 02:00 on Sunday 25 October. Each test also runs
with Django's TIME_ZONE set to London, so a future change that routes the
expansion through an aware datetime in the server's zone would fail here.
"""

import datetime

import pytest

from conftest import ClassScheduleFactory, DisciplineFactory, SemesterFactory, UserFactory
from study.services import class_occurrences

LONDON = "Europe/London"
MONDAY = 0
SUNDAY = 6
MORNING = (datetime.time(9, 0), datetime.time(10, 40))
# 01:30 does not exist in London on 29 March, and happens twice on 25 October.
AMBIGUOUS = (datetime.time(1, 30), datetime.time(2, 30))
MARCH = (datetime.date(2026, 3, 16), datetime.date(2026, 4, 12))
OCTOBER = (datetime.date(2026, 10, 12), datetime.date(2026, 11, 8))


def _weekly_class(user, day_of_week: int, times: tuple[datetime.time, datetime.time]):
    semester = SemesterFactory(user=user, start_date=datetime.date(2026, 2, 1), end_date=datetime.date(2026, 12, 18))
    return ClassScheduleFactory(
        discipline=DisciplineFactory(semester=semester),
        day_of_week=day_of_week,
        start_time=times[0],
        end_time=times[1],
    )


def _wall_clock(occurrences: list[dict]) -> list[tuple[datetime.date, datetime.time, datetime.time]]:
    return [(row["date"], row["start_time"], row["end_time"]) for row in occurrences]


def _weekly(first: datetime.date, count: int, times: tuple[datetime.time, datetime.time]) -> list:
    return [(first + datetime.timedelta(weeks=n), *times) for n in range(count)]


@pytest.fixture
def london(settings):
    settings.TIME_ZONE = LONDON
    return settings


@pytest.mark.django_db
class TestClassOccurrencesAcrossDst:
    def test_class_occurrences_keep_wall_clock_across_dst_m7(self, london):
        # March: the weeks before and after the clocks go forward.
        user = UserFactory()
        _weekly_class(user, MONDAY, MORNING)
        occurrences = class_occurrences(user, *MARCH)
        assert _wall_clock(occurrences) == _weekly(datetime.date(2026, 3, 16), 4, MORNING)

    def test_class_occurrences_keep_wall_clock_across_october_dst_m7(self, london):
        # October: the weeks before and after the clocks go back.
        user = UserFactory()
        _weekly_class(user, MONDAY, MORNING)
        occurrences = class_occurrences(user, *OCTOBER)
        assert _wall_clock(occurrences) == _weekly(datetime.date(2026, 10, 12), 4, MORNING)

    def test_class_on_the_transition_day_keeps_its_wall_clock_m7(self, london):
        # On the change day itself, at a local time that is skipped (March)
        # or repeated (October): the class is still at the time it was given.
        user = UserFactory()
        _weekly_class(user, SUNDAY, AMBIGUOUS)
        march = class_occurrences(user, datetime.date(2026, 3, 29), datetime.date(2026, 3, 29))
        october = class_occurrences(user, datetime.date(2026, 10, 25), datetime.date(2026, 10, 25))
        assert _wall_clock(march) == [(datetime.date(2026, 3, 29), *AMBIGUOUS)]
        assert _wall_clock(october) == [(datetime.date(2026, 10, 25), *AMBIGUOUS)]


@pytest.mark.django_db
class TestClassOccurrenceViewAcrossDst:
    @pytest.mark.parametrize(
        ("date_from", "date_to", "dates"),
        [
            ("2026-03-16", "2026-04-12", ["2026-03-16", "2026-03-23", "2026-03-30", "2026-04-06"]),
            ("2026-10-12", "2026-11-08", ["2026-10-12", "2026-10-19", "2026-10-26", "2026-11-02"]),
        ],
    )
    def test_view_returns_the_same_naive_times_on_both_sides_m7(
        self, london, authenticated_client, user, date_from, date_to, dates
    ):
        # The wire carries a date and an offset-free time: the client places
        # it on its own clock for that date (invariant 2), so no offset from
        # the server can leak into it.
        _weekly_class(user, MONDAY, MORNING)
        resp = authenticated_client.get(
            "/api/v1/study/class-occurrences/", {"date_from": date_from, "date_to": date_to}
        )
        assert resp.status_code == 200
        assert [(row["date"], row["start_time"], row["end_time"]) for row in resp.data] == [
            (day, "09:00:00", "10:40:00") for day in dates
        ]

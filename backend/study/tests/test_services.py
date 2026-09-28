import datetime

import pytest

from conftest import ClassScheduleFactory, DisciplineFactory, SemesterFactory, UserFactory
from study.services import class_occurrences

MON = datetime.date(2026, 3, 2)
FRI = datetime.date(2026, 3, 6)


def _schedule(user, day_of_week=0, **overrides):
    semester = SemesterFactory(user=user, start_date=datetime.date(2026, 3, 1), end_date=datetime.date(2026, 7, 15))
    discipline = DisciplineFactory(semester=semester, name="Calculo 2", color="#3b82f6")
    return ClassScheduleFactory(discipline=discipline, day_of_week=day_of_week, **overrides)


@pytest.mark.django_db
class TestClassOccurrences:
    def test_one_occurrence_per_matching_weekday(self):
        user = UserFactory()
        schedule = _schedule(user, day_of_week=2)

        occurrences = class_occurrences(user, MON, FRI)

        assert len(occurrences) == 1
        assert occurrences[0]["id"] == f"{schedule.id}-2026-03-04"
        assert occurrences[0]["class_schedule_id"] == schedule.id
        assert occurrences[0]["date"] == datetime.date(2026, 3, 4)
        assert occurrences[0]["discipline_name"] == "Calculo 2"
        assert occurrences[0]["discipline_color"] == "#3b82f6"
        assert occurrences[0]["start_time"] == schedule.start_time
        assert occurrences[0]["end_time"] == schedule.end_time

    def test_single_day_range_returns_that_days_classes(self):
        user = UserFactory()
        _schedule(user, day_of_week=0)
        _schedule(user, day_of_week=1)

        occurrences = class_occurrences(user, MON, MON)

        assert [o["date"] for o in occurrences] == [MON]

    def test_other_users_classes_are_not_returned(self):
        user = UserFactory()
        _schedule(UserFactory(), day_of_week=0)

        assert class_occurrences(user, MON, MON) == []

    def test_inactive_schedule_is_skipped(self):
        user = UserFactory()
        _schedule(user, day_of_week=0, is_active=False)

        assert class_occurrences(user, MON, MON) == []

    def test_range_outside_the_semester_is_empty(self):
        user = UserFactory()
        _schedule(user, day_of_week=0)

        assert class_occurrences(user, datetime.date(2026, 8, 3), datetime.date(2026, 8, 3)) == []

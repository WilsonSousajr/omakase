"""Week A/B rotation for class schedules (#126)."""

import datetime

import pytest
from django.db import IntegrityError
from rest_framework import status

from conftest import ClassScheduleFactory, DisciplineFactory, SemesterFactory, UserFactory
from study.services import class_occurrences, rotation_week

OCCURRENCES_URL = "/api/v1/study/class-occurrences/"
SEMESTERS_URL = "/api/v1/study/semesters/"
SCHEDULES_URL = "/api/v1/study/classschedules/"


def _rotating_schedule(user, weeks_on, rotation_weeks=2, anchor=None, day_of_week=0):
    semester = SemesterFactory(
        user=user,
        start_date=datetime.date(2026, 3, 1),
        end_date=datetime.date(2026, 7, 15),
        rotation_weeks=rotation_weeks,
        rotation_anchor=anchor,
    )
    discipline = DisciplineFactory(semester=semester)
    return ClassScheduleFactory(discipline=discipline, day_of_week=day_of_week, rotation_weeks_on=weeks_on)


class TestRotationWeek:
    # A Wednesday anchor counts from its Monday, so the whole anchor week is week 1.
    WED_ANCHOR = datetime.date(2026, 3, 4)

    def test_anchor_mid_week_makes_its_monday_week_one(self):
        assert rotation_week(datetime.date(2026, 3, 2), self.WED_ANCHOR, 2) == 1
        assert rotation_week(datetime.date(2026, 3, 8), self.WED_ANCHOR, 2) == 1

    def test_the_next_monday_starts_week_two(self):
        assert rotation_week(datetime.date(2026, 3, 9), self.WED_ANCHOR, 2) == 2
        assert rotation_week(datetime.date(2026, 3, 16), self.WED_ANCHOR, 2) == 1

    def test_counts_across_a_year_boundary(self):
        anchor = datetime.date(2026, 12, 30)  # a Wednesday; its Monday is 2026-12-28
        assert rotation_week(datetime.date(2027, 1, 1), anchor, 2) == 1
        assert rotation_week(datetime.date(2027, 1, 4), anchor, 2) == 2
        assert rotation_week(datetime.date(2027, 1, 11), anchor, 2) == 1
        assert rotation_week(datetime.date(2027, 1, 18), anchor, 3) == 1

    def test_a_date_before_the_anchor_still_rotates(self):
        assert rotation_week(datetime.date(2026, 2, 23), self.WED_ANCHOR, 2) == 2

    def test_rotation_of_one_is_always_week_one(self):
        assert rotation_week(datetime.date(2026, 5, 20), self.WED_ANCHOR, 1) == 1


@pytest.mark.django_db
class TestRotatingOccurrences:
    MARCH_2 = datetime.date(2026, 3, 2)
    MARCH_29 = datetime.date(2026, 3, 29)

    def test_week_two_class_skips_week_one_mondays(self):
        user = UserFactory()
        _rotating_schedule(user, weeks_on=[2], anchor=datetime.date(2026, 3, 4))

        occurrences = class_occurrences(user, self.MARCH_2, self.MARCH_29)

        assert [o["date"] for o in occurrences] == [datetime.date(2026, 3, 9), datetime.date(2026, 3, 23)]
        assert [o["week"] for o in occurrences] == [2, 2]

    def test_a_null_anchor_counts_from_the_semester_start(self):
        user = UserFactory()
        # The semester starts Sunday 2026-03-01, whose Monday is 2026-02-23: week 1.
        _rotating_schedule(user, weeks_on=[1], anchor=None)

        occurrences = class_occurrences(user, self.MARCH_2, self.MARCH_29)

        assert [o["date"] for o in occurrences] == [datetime.date(2026, 3, 9), datetime.date(2026, 3, 23)]

    def test_an_empty_list_means_every_week(self):
        user = UserFactory()
        _rotating_schedule(user, weeks_on=[], anchor=datetime.date(2026, 3, 2))

        occurrences = class_occurrences(user, self.MARCH_2, self.MARCH_29)

        assert [o["week"] for o in occurrences] == [1, 2, 1, 2]

    def test_rotation_one_is_every_week_as_before(self):
        user = UserFactory()
        _rotating_schedule(user, weeks_on=[], rotation_weeks=1)

        occurrences = class_occurrences(user, self.MARCH_2, self.MARCH_29)

        assert len(occurrences) == 4
        assert {o["week"] for o in occurrences} == {1}

    def test_another_users_rotation_does_not_leak(self):
        user, other = UserFactory(), UserFactory()
        _rotating_schedule(user, weeks_on=[1], anchor=datetime.date(2026, 3, 2))
        _rotating_schedule(other, weeks_on=[2], anchor=datetime.date(2026, 3, 2))

        occurrences = class_occurrences(user, self.MARCH_2, self.MARCH_29)

        assert [o["date"] for o in occurrences] == [datetime.date(2026, 3, 2), datetime.date(2026, 3, 16)]


@pytest.mark.django_db
class TestRotationEndpoints:
    def test_occurrences_carry_the_week(self, authenticated_client, user):
        _rotating_schedule(user, weeks_on=[2], anchor=datetime.date(2026, 3, 2))

        resp = authenticated_client.get(f"{OCCURRENCES_URL}?date_from=2026-03-02&date_to=2026-03-15")

        assert resp.status_code == status.HTTP_200_OK
        assert [(o["date"], o["week"]) for o in resp.data] == [("2026-03-09", 2)]

    def test_semester_exposes_rotation_fields(self, authenticated_client, user):
        resp = authenticated_client.post(
            SEMESTERS_URL,
            {"name": "S", "start_date": "2026-03-01", "end_date": "2026-07-15", "rotation_weeks": 2},
            format="json",
        )

        assert resp.status_code == status.HTTP_201_CREATED, resp.content
        assert resp.data["rotation_weeks"] == 2
        assert resp.data["rotation_anchor"] is None

    @pytest.mark.parametrize("weeks", [0, 5])
    def test_rotation_outside_one_to_four_is_a_400(self, authenticated_client, weeks):
        resp = authenticated_client.post(
            SEMESTERS_URL,
            {"name": "S", "start_date": "2026-03-01", "end_date": "2026-07-15", "rotation_weeks": weeks},
            format="json",
        )

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        message = str(resp.data["rotation_weeks"])
        assert str(weeks) in message
        assert "1-4" in message

    def test_schedule_weeks_are_stored(self, authenticated_client, user):
        discipline = DisciplineFactory(semester=SemesterFactory(user=user, rotation_weeks=2))

        resp = authenticated_client.post(SCHEDULES_URL, self._schedule_body(discipline, [2]), format="json")

        assert resp.status_code == status.HTTP_201_CREATED, resp.content
        assert resp.data["rotation_weeks_on"] == [2]

    def test_schedule_week_beyond_the_rotation_is_a_400(self, authenticated_client, user):
        discipline = DisciplineFactory(semester=SemesterFactory(user=user, rotation_weeks=2))

        resp = authenticated_client.post(SCHEDULES_URL, self._schedule_body(discipline, [1, 3]), format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        message = str(resp.data["rotation_weeks_on"])
        assert "3" in message
        assert "1-2" in message

    @pytest.mark.parametrize("weeks_on", [["a"], [True], [1.5], "1", {"week": 1}])
    def test_schedule_weeks_must_be_a_list_of_ints(self, authenticated_client, user, weeks_on):
        discipline = DisciplineFactory(semester=SemesterFactory(user=user, rotation_weeks=2))

        resp = authenticated_client.post(SCHEDULES_URL, self._schedule_body(discipline, weeks_on), format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "rotation_weeks_on" in resp.data

    def test_patching_weeks_validates_against_the_existing_semester(self, authenticated_client, user):
        schedule = _rotating_schedule(user, weeks_on=[], rotation_weeks=2)

        resp = authenticated_client.patch(f"{SCHEDULES_URL}{schedule.pk}/", {"rotation_weeks_on": [3]}, format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_shrinking_a_rotation_below_a_used_week_is_a_400(self, authenticated_client, user):
        schedule = _rotating_schedule(user, weeks_on=[3], rotation_weeks=3)
        semester = schedule.discipline.semester

        resp = authenticated_client.patch(f"{SEMESTERS_URL}{semester.pk}/", {"rotation_weeks": 2}, format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "3" in str(resp.data["rotation_weeks"])

    @staticmethod
    def _schedule_body(discipline, weeks_on):
        return {
            "discipline": str(discipline.pk),
            "day_of_week": 0,
            "start_time": "10:00",
            "end_time": "11:40",
            "rotation_weeks_on": weeks_on,
        }


@pytest.mark.django_db
def test_rotation_outside_one_to_four_is_rejected_by_the_database():
    with pytest.raises(IntegrityError):
        SemesterFactory(rotation_weeks=5)

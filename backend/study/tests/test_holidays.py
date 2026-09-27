"""Holidays suppress class occurrences (#125)."""

import datetime

import pytest
from django.db import IntegrityError
from rest_framework import status

from conftest import ClassScheduleFactory, DisciplineFactory, HolidayFactory, SemesterFactory, UserFactory
from study.services import class_occurrences

HOLIDAYS_URL = "/api/v1/study/holidays/"
MARCH_2 = datetime.date(2026, 3, 2)
MARCH_29 = datetime.date(2026, 3, 29)


def _monday_class(user):
    semester = SemesterFactory(user=user, start_date=datetime.date(2026, 3, 1), end_date=datetime.date(2026, 7, 15))
    ClassScheduleFactory(discipline=DisciplineFactory(semester=semester), day_of_week=0)
    return semester


@pytest.mark.django_db
class TestHolidayExpansion:
    def test_a_holiday_omits_the_classes_inside_it(self):
        user = UserFactory()
        semester = _monday_class(user)
        HolidayFactory(semester=semester, start_date=datetime.date(2026, 3, 7), end_date=datetime.date(2026, 3, 13))

        dates = [o["date"] for o in class_occurrences(user, MARCH_2, MARCH_29)]

        assert dates == [datetime.date(2026, 3, 2), datetime.date(2026, 3, 16), datetime.date(2026, 3, 23)]

    def test_the_start_date_is_inside_the_holiday(self):
        user = UserFactory()
        semester = _monday_class(user)
        HolidayFactory(semester=semester, start_date=datetime.date(2026, 3, 9), end_date=datetime.date(2026, 3, 11))

        dates = [o["date"] for o in class_occurrences(user, MARCH_2, MARCH_29)]

        assert datetime.date(2026, 3, 9) not in dates
        assert len(dates) == 3

    def test_the_end_date_is_inside_the_holiday(self):
        user = UserFactory()
        semester = _monday_class(user)
        HolidayFactory(semester=semester, start_date=datetime.date(2026, 3, 5), end_date=datetime.date(2026, 3, 9))

        dates = [o["date"] for o in class_occurrences(user, MARCH_2, MARCH_29)]

        assert datetime.date(2026, 3, 9) not in dates
        assert len(dates) == 3

    def test_a_one_day_holiday_omits_that_day_only(self):
        user = UserFactory()
        semester = _monday_class(user)
        HolidayFactory(semester=semester, start_date=datetime.date(2026, 3, 16), end_date=datetime.date(2026, 3, 16))

        dates = [o["date"] for o in class_occurrences(user, MARCH_2, MARCH_29)]

        assert dates == [datetime.date(2026, 3, 2), datetime.date(2026, 3, 9), datetime.date(2026, 3, 23)]

    def test_another_semesters_holiday_does_not_apply(self):
        user = UserFactory()
        _monday_class(user)
        other = SemesterFactory(user=user)
        HolidayFactory(semester=other, start_date=MARCH_2, end_date=MARCH_29)

        assert len(class_occurrences(user, MARCH_2, MARCH_29)) == 4

    def test_another_users_holiday_does_not_apply(self):
        user = UserFactory()
        _monday_class(user)
        HolidayFactory(semester__user=UserFactory(), start_date=MARCH_2, end_date=MARCH_29)

        assert len(class_occurrences(user, MARCH_2, MARCH_29)) == 4


@pytest.mark.django_db
class TestHolidayViewSet:
    def test_unauthenticated_returns_401(self, api_client):
        assert api_client.get(HOLIDAYS_URL).status_code == status.HTTP_401_UNAUTHORIZED

    def test_create_a_holiday(self, authenticated_client, semester):
        resp = authenticated_client.post(HOLIDAYS_URL, self._body(semester, "2026-04-03", "2026-04-10"), format="json")

        assert resp.status_code == status.HTTP_201_CREATED, resp.content
        assert resp.data["name"] == "Easter"
        assert str(resp.data["semester"]) == str(semester.pk)

    def test_a_one_day_holiday_is_valid(self, authenticated_client, semester):
        resp = authenticated_client.post(HOLIDAYS_URL, self._body(semester, "2026-04-03", "2026-04-03"), format="json")

        assert resp.status_code == status.HTTP_201_CREATED

    def test_end_before_start_is_a_400(self, authenticated_client, semester):
        resp = authenticated_client.post(HOLIDAYS_URL, self._body(semester, "2026-04-10", "2026-04-03"), format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        message = str(resp.data)
        assert "2026-04-03" in message
        assert "2026-04-10" in message

    def test_patching_end_before_the_stored_start_is_a_400(self, authenticated_client, user):
        holiday = HolidayFactory(semester__user=user, start_date=datetime.date(2026, 4, 3))

        resp = authenticated_client.patch(f"{HOLIDAYS_URL}{holiday.pk}/", {"end_date": "2026-04-01"}, format="json")

        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_list_is_scoped_to_the_user(self, authenticated_client, user):
        HolidayFactory.create_batch(2, semester__user=user)
        HolidayFactory.create_batch(3)

        resp = authenticated_client.get(HOLIDAYS_URL)

        assert resp.data["count"] == 2

    def test_filter_by_semester(self, authenticated_client, user):
        semester = SemesterFactory(user=user)
        HolidayFactory(semester=semester)
        HolidayFactory(semester__user=user)

        resp = authenticated_client.get(f"{HOLIDAYS_URL}?semester={semester.pk}")

        assert resp.data["count"] == 1

    def test_another_users_holiday_is_a_404(self, authenticated_client):
        holiday = HolidayFactory()

        assert authenticated_client.get(f"{HOLIDAYS_URL}{holiday.pk}/").status_code == status.HTTP_404_NOT_FOUND
        assert authenticated_client.delete(f"{HOLIDAYS_URL}{holiday.pk}/").status_code == status.HTTP_404_NOT_FOUND

    def test_creating_on_another_users_semester_is_refused(self, authenticated_client):
        foreign = SemesterFactory()

        resp = authenticated_client.post(HOLIDAYS_URL, self._body(foreign, "2026-04-03", "2026-04-10"), format="json")

        assert resp.status_code in (status.HTTP_400_BAD_REQUEST, status.HTTP_403_FORBIDDEN)
        assert not foreign.holidays.exists()

    def test_moving_a_holiday_to_another_users_semester_is_refused(self, authenticated_client, user):
        holiday = HolidayFactory(semester__user=user)
        foreign = SemesterFactory()

        resp = authenticated_client.patch(f"{HOLIDAYS_URL}{holiday.pk}/", {"semester": str(foreign.pk)}, format="json")

        assert resp.status_code in (status.HTTP_400_BAD_REQUEST, status.HTTP_403_FORBIDDEN)
        holiday.refresh_from_db()
        assert holiday.semester.user == user

    def test_delete_a_holiday(self, authenticated_client, user):
        holiday = HolidayFactory(semester__user=user)

        assert authenticated_client.delete(f"{HOLIDAYS_URL}{holiday.pk}/").status_code == status.HTTP_204_NO_CONTENT

    @staticmethod
    def _body(semester, start, end):
        return {"semester": str(semester.pk), "name": "Easter", "start_date": start, "end_date": end}


@pytest.mark.django_db
def test_holiday_ending_before_it_starts_is_rejected_by_the_database():
    with pytest.raises(IntegrityError):
        HolidayFactory(start_date=datetime.date(2026, 4, 10), end_date=datetime.date(2026, 4, 3))

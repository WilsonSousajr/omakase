"""Cancelling and restoring one class occurrence (#125)."""

import datetime

import pytest
from django.db import IntegrityError
from rest_framework import status

from conftest import (
    ClassCancellationFactory,
    ClassScheduleFactory,
    DisciplineFactory,
    HolidayFactory,
    SemesterFactory,
    UserFactory,
)
from study.models import ClassCancellation
from study.services import class_occurrences

SCHEDULES_URL = "/api/v1/study/classschedules/"
OCCURRENCES_URL = "/api/v1/study/class-occurrences/"
MARCH_2 = datetime.date(2026, 3, 2)
MARCH_9 = datetime.date(2026, 3, 9)


def _monday_class(user, **semester_fields):
    semester = SemesterFactory(
        user=user, start_date=datetime.date(2026, 3, 1), end_date=datetime.date(2026, 7, 15), **semester_fields
    )
    return ClassScheduleFactory(discipline=DisciplineFactory(semester=semester), day_of_week=0)


def _url(schedule, day):
    return f"{SCHEDULES_URL}{schedule.pk}/cancellations/{day}/"


@pytest.mark.django_db
class TestCancelledOccurrences:
    def test_a_cancelled_occurrence_is_returned_marked(self):
        user = UserFactory()
        schedule = _monday_class(user)
        ClassCancellationFactory(class_schedule=schedule, date=MARCH_9)

        occurrences = class_occurrences(user, MARCH_2, MARCH_9)

        assert [(o["date"], o["is_cancelled"]) for o in occurrences] == [(MARCH_2, False), (MARCH_9, True)]

    def test_expansion_is_a_constant_number_of_queries(self, django_assert_num_queries):
        user = UserFactory()
        for _ in range(4):
            schedule = _monday_class(user)
            HolidayFactory(semester=schedule.discipline.semester, start_date=MARCH_9, end_date=MARCH_9)
            ClassCancellationFactory(class_schedule=schedule, date=MARCH_2)

        # schedules (with discipline and semester), holidays, cancellations
        with django_assert_num_queries(3):
            occurrences = class_occurrences(user, MARCH_2, datetime.date(2026, 3, 29))

        # 4 schedules x Mondays 2, 16 and 23 March; the 9th is a holiday.
        assert len(occurrences) == 12
        assert sum(o["is_cancelled"] for o in occurrences) == 4


@pytest.mark.django_db
class TestCancelEndpoint:
    def test_cancel_creates_one_cancellation(self, authenticated_client, user):
        schedule = _monday_class(user)

        resp = authenticated_client.put(_url(schedule, "2026-03-09"))

        assert resp.status_code == status.HTTP_201_CREATED, resp.content
        assert resp.data["date"] == "2026-03-09"
        assert str(resp.data["class_schedule"]) == str(schedule.pk)
        assert ClassCancellation.objects.filter(class_schedule=schedule, date=MARCH_9).count() == 1

    def test_cancelling_twice_keeps_one_row(self, authenticated_client, user):
        schedule = _monday_class(user)

        authenticated_client.put(_url(schedule, "2026-03-09"))
        resp = authenticated_client.put(_url(schedule, "2026-03-09"))

        assert resp.status_code == status.HTTP_200_OK
        assert ClassCancellation.objects.filter(class_schedule=schedule).count() == 1

    def test_cancelled_occurrence_shows_in_the_occurrences(self, authenticated_client, user):
        schedule = _monday_class(user)
        authenticated_client.put(_url(schedule, "2026-03-09"))

        resp = authenticated_client.get(f"{OCCURRENCES_URL}?date_from=2026-03-02&date_to=2026-03-15")

        assert [(o["date"], o["is_cancelled"]) for o in resp.data] == [("2026-03-02", False), ("2026-03-09", True)]

    def test_restore_removes_the_cancellation(self, authenticated_client, user):
        schedule = _monday_class(user)
        ClassCancellationFactory(class_schedule=schedule, date=MARCH_9)

        resp = authenticated_client.delete(_url(schedule, "2026-03-09"))

        assert resp.status_code == status.HTTP_204_NO_CONTENT
        assert not ClassCancellation.objects.filter(class_schedule=schedule).exists()

    def test_restoring_an_uncancelled_class_is_a_204(self, authenticated_client, user):
        schedule = _monday_class(user)

        assert authenticated_client.delete(_url(schedule, "2026-03-09")).status_code == status.HTTP_204_NO_CONTENT

    def test_cancel_on_the_wrong_weekday_is_a_400(self, authenticated_client, user):
        schedule = _monday_class(user)

        resp = authenticated_client.put(_url(schedule, "2026-03-10"))

        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "2026-03-10" in str(resp.data["date"])
        assert not ClassCancellation.objects.exists()

    def test_cancel_outside_the_semester_is_a_400(self, authenticated_client, user):
        schedule = _monday_class(user)

        assert authenticated_client.put(_url(schedule, "2026-08-03")).status_code == status.HTTP_400_BAD_REQUEST

    def test_cancel_in_an_off_rotation_week_is_a_400(self, authenticated_client, user):
        schedule = _monday_class(user, rotation_weeks=2, rotation_anchor=MARCH_2)
        schedule.rotation_weeks_on = [1]
        schedule.save()

        assert authenticated_client.put(_url(schedule, "2026-03-09")).status_code == status.HTTP_400_BAD_REQUEST
        assert authenticated_client.put(_url(schedule, "2026-03-16")).status_code == status.HTTP_201_CREATED

    def test_cancel_during_a_holiday_is_a_400(self, authenticated_client, user):
        schedule = _monday_class(user)
        HolidayFactory(semester=schedule.discipline.semester, start_date=MARCH_9, end_date=MARCH_9)

        assert authenticated_client.put(_url(schedule, "2026-03-09")).status_code == status.HTTP_400_BAD_REQUEST

    def test_cancel_an_inactive_schedule_is_a_400(self, authenticated_client, user):
        schedule = _monday_class(user)
        schedule.is_active = False
        schedule.save()

        assert authenticated_client.put(_url(schedule, "2026-03-09")).status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.parametrize("day", ["20260309", "2026-02-30", "tomorrow"])
    def test_a_malformed_date_is_a_400(self, authenticated_client, user, day):
        schedule = _monday_class(user)

        assert authenticated_client.put(_url(schedule, day)).status_code == status.HTTP_400_BAD_REQUEST

    def test_another_users_schedule_is_a_404(self, authenticated_client):
        schedule = _monday_class(UserFactory())

        assert authenticated_client.put(_url(schedule, "2026-03-09")).status_code == status.HTTP_404_NOT_FOUND
        assert authenticated_client.delete(_url(schedule, "2026-03-09")).status_code == status.HTTP_404_NOT_FOUND
        assert not ClassCancellation.objects.exists()

    def test_another_users_cancellation_does_not_show(self, authenticated_client, user):
        _monday_class(user)
        ClassCancellationFactory(class_schedule=_monday_class(UserFactory()), date=MARCH_9)

        resp = authenticated_client.get(f"{OCCURRENCES_URL}?date_from=2026-03-09&date_to=2026-03-09")

        assert [o["is_cancelled"] for o in resp.data] == [False]


@pytest.mark.django_db
def test_one_cancellation_per_schedule_and_date_in_the_database():
    cancellation = ClassCancellationFactory(date=MARCH_9)
    with pytest.raises(IntegrityError):
        ClassCancellationFactory(class_schedule=cancellation.class_schedule, date=MARCH_9)

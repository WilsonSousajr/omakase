"""The rule's validation (invariant 3) and the series keys on every task (#124)."""

import datetime

import pytest

from conftest import TaskFactory
from tasks.models import TaskRecurrence
from tasks.serializers import TaskDayListSerializer, TaskListSerializer, TaskRecurrenceSerializer

VALID = {"freq": "weekly", "interval": 1, "weekdays": [0, 2], "starts_on": "2026-03-02", "until": None}


def _errors(**overrides) -> dict:
    serializer = TaskRecurrenceSerializer(data={**VALID, **overrides})
    assert not serializer.is_valid()
    return serializer.errors


class TestTaskRecurrenceSerializer:
    def test_a_valid_rule(self):
        serializer = TaskRecurrenceSerializer(data=VALID)
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data["weekdays"] == [0, 2]

    def test_interval_and_weekdays_and_until_default(self):
        serializer = TaskRecurrenceSerializer(data={"freq": "daily", "starts_on": "2026-03-02"})
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data["interval"] == 1
        assert serializer.validated_data["weekdays"] == []
        assert serializer.validated_data.get("until") is None

    def test_weekdays_are_sorted_and_deduplicated(self):
        serializer = TaskRecurrenceSerializer(data={**VALID, "weekdays": [4, 0, 4]})
        assert serializer.is_valid(), serializer.errors
        assert serializer.validated_data["weekdays"] == [0, 4]

    @pytest.mark.parametrize("interval", [0, 31])
    def test_interval_outside_1_to_30_names_the_value(self, interval):
        message = str(_errors(interval=interval)["interval"][0])
        assert str(interval) in message
        assert "1-30" in message

    def test_unknown_freq_names_the_value_and_the_choices(self):
        message = str(_errors(freq="yearly")["freq"][0])
        assert "yearly" in message
        assert "daily, weekly or monthly" in message

    @pytest.mark.parametrize("weekdays", [[7], [-1], ["mon"], [True], "0,2", [1.5]])
    def test_weekdays_outside_0_to_6_names_the_value(self, weekdays):
        message = str(_errors(weekdays=weekdays)["weekdays"][0])
        assert repr(weekdays) in message
        assert "0 (Monday) to 6 (Sunday)" in message

    def test_weekdays_on_a_monthly_rule_are_refused(self):
        message = str(_errors(freq="monthly", weekdays=[1])["weekdays"][0])
        assert "[1]" in message
        assert "monthly" in message

    def test_until_before_starts_on_names_both(self):
        message = str(_errors(until="2026-03-01")["until"][0])
        assert "2026-03-01" in message
        assert "2026-03-02" in message

    def test_until_on_starts_on_is_a_one_day_series(self):
        assert TaskRecurrenceSerializer(data={**VALID, "until": "2026-03-02"}).is_valid()


@pytest.mark.django_db
class TestSeriesKeysOnTasks:
    def test_a_plain_task_carries_the_series_keys_empty(self, user):
        data = TaskListSerializer(TaskFactory(user=user)).data
        assert data["series"] is None
        assert data["occurrence_date"] is None
        assert data["is_skipped"] is False
        assert data["is_virtual"] is False
        assert data["recurrence"] is None

    def test_a_template_embeds_its_rule(self, user):
        template = TaskFactory(user=user)
        TaskRecurrence.objects.create(task=template, freq="weekly", weekdays=[0], starts_on=datetime.date(2026, 3, 2))
        data = TaskListSerializer(template).data
        assert data["recurrence"] == {
            "freq": "weekly",
            "interval": 1,
            "weekdays": [0],
            "starts_on": "2026-03-02",
            "until": None,
        }

    def test_an_occurrence_embeds_its_series_rule(self, user):
        template = TaskFactory(user=user)
        TaskRecurrence.objects.create(task=template, freq="daily", starts_on=datetime.date(2026, 3, 2))
        occurrence = TaskFactory(user=user, series=template, occurrence_date=datetime.date(2026, 3, 3))
        data = TaskDayListSerializer(occurrence).data
        assert data["series"] == template.pk
        assert data["occurrence_date"] == "2026-03-03"
        assert data["recurrence"]["freq"] == "daily"

    def test_series_fields_are_not_writable_through_tasks(self, user):
        template = TaskFactory(user=user)
        task = TaskFactory(user=user)
        serializer = TaskListSerializer(
            task,
            data={"series": str(template.pk), "occurrence_date": "2026-03-02", "is_skipped": True},
            partial=True,
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        task.refresh_from_db()
        assert (task.series, task.occurrence_date, task.is_skipped) == (None, None, False)

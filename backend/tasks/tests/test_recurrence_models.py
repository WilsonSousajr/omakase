"""The series fields and the rule's database safety nets (#124, M8 design §2)."""

import datetime

import pytest
from django.db import IntegrityError, transaction

from conftest import TaskFactory
from tasks.models import TaskRecurrence

MONDAY = datetime.date(2026, 3, 2)


def _rule(template, **overrides) -> TaskRecurrence:
    values = {"freq": "weekly", "interval": 1, "weekdays": [], "starts_on": MONDAY, "until": None}
    values.update(overrides)
    return TaskRecurrence.objects.create(task=template, **values)


@pytest.mark.django_db
class TestTaskRecurrenceModel:
    def test_a_task_with_a_rule_is_a_series_template(self, user):
        template = TaskFactory(user=user)
        _rule(template)
        template.refresh_from_db()
        assert template.recurrence.freq == "weekly"
        assert template.series_rule == template.recurrence

    def test_an_occurrence_reads_its_series_rule(self, user):
        template = TaskFactory(user=user)
        rule = _rule(template)
        occurrence = TaskFactory(user=user, series=template, occurrence_date=MONDAY)
        assert occurrence.series_rule == rule

    def test_a_plain_task_has_no_rule(self, user):
        assert TaskFactory(user=user).series_rule is None

    @pytest.mark.parametrize("interval", [0, 31])
    def test_interval_outside_1_to_30_is_refused_by_the_database(self, user, interval):
        with pytest.raises(IntegrityError), transaction.atomic():
            _rule(TaskFactory(user=user), interval=interval)

    def test_until_two_days_before_starts_on_is_refused_by_the_database(self, user):
        with pytest.raises(IntegrityError), transaction.atomic():
            _rule(TaskFactory(user=user), until=MONDAY - datetime.timedelta(days=2))

    def test_until_the_day_before_starts_on_marks_a_series_stopped_before_it_began(self, user):
        # DELETE recurrence/ on or before starts_on sets until = starts_on - 1:
        # an empty series, not a constraint violation (M8 design §2).
        rule = _rule(TaskFactory(user=user), until=MONDAY - datetime.timedelta(days=1))
        assert rule.until == datetime.date(2026, 3, 1)

    def test_deleting_the_template_deletes_its_rule(self, user):
        template = TaskFactory(user=user)
        _rule(template)
        template.delete()
        assert not TaskRecurrence.objects.exists()


@pytest.mark.django_db
class TestOccurrenceRows:
    def test_two_rows_for_one_series_and_date_are_refused(self, user):
        template = TaskFactory(user=user)
        TaskFactory(user=user, series=template, occurrence_date=MONDAY)
        with pytest.raises(IntegrityError), transaction.atomic():
            TaskFactory(user=user, series=template, occurrence_date=MONDAY)

    def test_plain_tasks_are_not_held_to_the_uniqueness(self, user):
        TaskFactory(user=user)
        TaskFactory(user=user)

    def test_series_without_occurrence_date_is_refused(self, user):
        template = TaskFactory(user=user)
        with pytest.raises(IntegrityError), transaction.atomic():
            TaskFactory(user=user, series=template, occurrence_date=None)

    def test_occurrence_date_without_series_is_refused(self, user):
        with pytest.raises(IntegrityError), transaction.atomic():
            TaskFactory(user=user, occurrence_date=MONDAY)

    def test_deleting_the_template_deletes_its_occurrences(self, user):
        template = TaskFactory(user=user)
        TaskFactory(user=user, series=template, occurrence_date=MONDAY)
        template.delete()
        assert not TaskFactory._meta.model.objects.filter(occurrence_date=MONDAY).exists()

    def test_is_skipped_defaults_to_false(self, user):
        assert TaskFactory(user=user).is_skipped is False

"""A day's (or a range's) tasks: concrete rows plus computed occurrences (#124)."""

import datetime

import pytest

from conftest import TaskFactory, UserFactory
from tasks.models import Task, TaskRecurrence
from tasks.services import VirtualOccurrence, day_items

MONDAY = datetime.date(2026, 3, 2)
WEDNESDAY = datetime.date(2026, 3, 4)


def series(user, **rule) -> Task:
    template = TaskFactory(user=user, title="Stand-up", estimated_minutes=15)
    values = {"freq": "weekly", "weekdays": [0, 2], "starts_on": MONDAY}
    values.update(rule)
    TaskRecurrence.objects.create(task=template, **values)
    return template


def virtual(items) -> list[VirtualOccurrence]:
    return [item for item in items if isinstance(item, VirtualOccurrence)]


@pytest.mark.django_db
class TestDayItems:
    def test_a_rule_date_without_a_row_is_a_virtual_occurrence(self, user):
        template = series(user)
        [item] = day_items(user, MONDAY, MONDAY)
        assert item == VirtualOccurrence(template=template, day=MONDAY)
        assert item.estimated_minutes == 15
        assert item.scheduled_date == MONDAY

    def test_the_template_itself_is_never_a_day_item(self, user):
        template = series(user)
        Task.objects.filter(pk=template.pk).update(scheduled_date=MONDAY)
        assert all(item != template for item in day_items(user, MONDAY, MONDAY))

    def test_a_concrete_row_replaces_the_virtual_one(self, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY)
        assert day_items(user, MONDAY, MONDAY) == [row]

    def test_a_moved_row_keeps_its_identity_and_shows_on_its_new_day(self, user):
        template = series(user)
        row = TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=datetime.date(2026, 3, 3))
        assert day_items(user, MONDAY, MONDAY) == []
        assert day_items(user, datetime.date(2026, 3, 3), datetime.date(2026, 3, 3)) == [row]

    def test_a_skipped_row_hides_the_occurrence(self, user):
        template = series(user)
        TaskFactory(user=user, series=template, occurrence_date=MONDAY, scheduled_date=MONDAY, is_skipped=True)
        assert day_items(user, MONDAY, MONDAY) == []

    def test_plain_tasks_on_the_day_are_included(self, user):
        plain = TaskFactory(user=user, scheduled_date=MONDAY)
        TaskFactory(user=user, scheduled_date=WEDNESDAY)
        assert day_items(user, MONDAY, MONDAY) == [plain]

    def test_a_range_is_ordered_by_date(self, user):
        template = series(user)
        plain = TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 3))
        items = day_items(user, MONDAY, WEDNESDAY)
        assert items == [
            VirtualOccurrence(template=template, day=MONDAY),
            plain,
            VirtualOccurrence(template=template, day=WEDNESDAY),
        ]

    def test_an_ended_series_adds_nothing_after_until(self, user):
        series(user, until=MONDAY)
        assert [item.day for item in virtual(day_items(user, MONDAY, WEDNESDAY))] == [MONDAY]

    def test_another_users_series_and_rows_are_invisible(self, user):
        other = UserFactory()
        template = series(other)
        TaskFactory(user=other, scheduled_date=MONDAY)
        TaskFactory(user=other, series=template, occurrence_date=WEDNESDAY, scheduled_date=MONDAY)
        assert day_items(user, MONDAY, WEDNESDAY) == []

    def test_query_count_does_not_grow_with_the_number_of_series(self, user, django_assert_num_queries):
        series(user)
        TaskFactory(user=user, scheduled_date=MONDAY)
        # rows + their 3 prefetches, templates + their 3 prefetches, stored (series, date) keys.
        with django_assert_num_queries(9):
            day_items(user, MONDAY, WEDNESDAY)
        for _ in range(4):
            series(user)
        with django_assert_num_queries(9):
            items = day_items(user, MONDAY, WEDNESDAY)
        assert len(virtual(items)) == 10

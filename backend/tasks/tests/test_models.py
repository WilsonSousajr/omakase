import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError

from conftest import TagFactory, TaskFactory, TimeBlockFactory
from tasks.models import Tag, Task, TimeBlock


@pytest.mark.django_db
class TestTag:
    def test_creation(self):
        tag = TagFactory(name="Backend")
        assert tag.name == "Backend"
        assert tag.pk is not None

    def test_defaults(self):
        tag = TagFactory()
        assert tag.area == "work"
        assert tag.color == "#6366f1"

    def test_hex_color_valid(self):
        tag = TagFactory(color="#ff0000")
        tag.full_clean()

    def test_hex_color_invalid(self):
        tag = TagFactory.build(color="notacolor")
        with pytest.raises(ValidationError):
            tag.full_clean()

    def test_hex_color_invalid_short(self):
        tag = TagFactory.build(color="#fff")
        with pytest.raises(ValidationError):
            tag.full_clean()

    def test_ordering_by_name(self):
        TagFactory(name="Zebra")
        TagFactory(name="Alpha")
        names = list(Tag.objects.values_list("name", flat=True))
        assert names == sorted(names)

    def test_str_representation(self):
        tag = TagFactory(name="Design")
        assert str(tag) == "Design"


@pytest.mark.django_db
class TestTask:
    def test_creation(self):
        task = TaskFactory(title="Write tests")
        assert task.title == "Write tests"
        assert task.pk is not None

    def test_defaults(self):
        task = TaskFactory()
        assert task.priority == "medium"
        assert task.kanban_status == "todo"
        assert task.description == ""
        assert task.notes == ""
        assert task.is_completed is False
        assert task.completed_at is None
        assert task.kanban_order == 0

    def test_ordering(self):
        t1 = TaskFactory(kanban_order=1)
        t2 = TaskFactory(kanban_order=0)
        tasks = list(Task.objects.all())
        assert tasks[0] == t2
        assert tasks[1] == t1

    def test_str_representation(self):
        task = TaskFactory(title="Ship it")
        assert str(task) == "Ship it"

    def test_tag_m2m_add(self):
        task = TaskFactory()
        tag = TagFactory()
        task.tags.add(tag)
        assert tag in task.tags.all()

    def test_tag_m2m_remove(self):
        tag = TagFactory()
        task = TaskFactory(tags=[tag])
        task.tags.remove(tag)
        assert tag not in task.tags.all()


@pytest.mark.django_db
class TestTimeBlock:
    def test_creation(self):
        tb = TimeBlockFactory()
        assert tb.pk is not None
        assert tb.task is not None

    def test_constraint_end_after_start(self):
        import datetime
        with pytest.raises(IntegrityError):
            TimeBlockFactory(
                start_time=datetime.time(10, 0),
                end_time=datetime.time(9, 0),
            )

    def test_constraint_equal_times(self):
        import datetime
        with pytest.raises(IntegrityError):
            TimeBlockFactory(
                start_time=datetime.time(10, 0),
                end_time=datetime.time(10, 0),
            )

    def test_cascade_delete_on_task(self):
        tb = TimeBlockFactory()
        task_id = tb.task.pk
        tb.task.delete()
        assert not TimeBlock.objects.filter(task_id=task_id).exists()

    def test_ordering_by_date_start_time(self):
        import datetime
        TimeBlockFactory(date=datetime.date(2025, 1, 2), start_time=datetime.time(8, 0), end_time=datetime.time(9, 0))
        TimeBlockFactory(date=datetime.date(2025, 1, 1), start_time=datetime.time(10, 0), end_time=datetime.time(11, 0))
        blocks = list(TimeBlock.objects.all())
        assert blocks[0].date < blocks[1].date

    def test_str_representation(self):
        tb = TimeBlockFactory()
        result = str(tb)
        assert tb.task.title in result
        assert str(tb.date) in result

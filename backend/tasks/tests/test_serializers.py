import pytest
from django.utils import timezone

from conftest import DisciplineFactory, StudyBlockFactory, TagFactory, TaskFactory
from tasks.serializers import (
    TagSerializer,
    TaskListSerializer,
    TaskReorderSerializer,
    TaskSerializer,
    TimeBlockSerializer,
)


@pytest.mark.django_db
class TestTagSerializer:
    def test_valid_create(self):
        data = {"name": "Backend", "color": "#ff0000", "area": "work"}
        serializer = TagSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        tag = serializer.save()
        assert tag.name == "Backend"

    def test_hex_color_rejection(self):
        data = {"name": "Bad", "color": "notacolor", "area": "work"}
        serializer = TagSerializer(data=data)
        assert not serializer.is_valid()
        assert "color" in serializer.errors

    def test_read_only_fields(self):
        tag = TagFactory()
        data = TagSerializer(tag).data
        assert "id" in data
        assert "created_at" in data


@pytest.mark.django_db
class TestTaskListSerializer:
    def test_create_with_tag_ids(self):
        tag = TagFactory()
        data = {"title": "Test task", "tag_ids": [str(tag.pk)]}
        serializer = TaskListSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        task = serializer.save()
        assert tag in task.tags.all()

    def test_update_completes_task(self):
        task = TaskFactory(is_completed=False)
        serializer = TaskListSerializer(task, data={"is_completed": True}, partial=True)
        assert serializer.is_valid(), serializer.errors
        updated = serializer.save()
        assert updated.completed_at is not None

    def test_update_uncompletes_task(self):
        task = TaskFactory(is_completed=True, completed_at=timezone.now())
        serializer = TaskListSerializer(task, data={"is_completed": False}, partial=True)
        assert serializer.is_valid(), serializer.errors
        updated = serializer.save()
        assert updated.completed_at is None

    def test_tags_nested_on_read(self):
        tag = TagFactory(name="Frontend")
        task = TaskFactory(tags=[tag])
        data = TaskListSerializer(task).data
        assert len(data["tags"]) == 1
        assert data["tags"][0]["name"] == "Frontend"


@pytest.mark.django_db
class TestTaskSerializer:
    def test_includes_notes_and_time_blocks(self):
        task = TaskFactory(notes="Some notes")
        data = TaskSerializer(task).data
        assert "notes" in data
        assert "time_blocks" in data
        assert data["notes"] == "Some notes"


@pytest.mark.django_db
class TestTaskDisciplineFK:
    def test_task_with_discipline_serializes(self):
        discipline = DisciplineFactory()
        task = TaskFactory(discipline=discipline, area="study")
        data = TaskListSerializer(task).data
        assert str(data["discipline"]) == str(discipline.pk)
        assert data["area"] == "study"

    def test_task_create_with_discipline(self):
        discipline = DisciplineFactory()
        data = {
            "title": "Study integrals",
            "area": "study",
            "discipline": str(discipline.pk),
        }
        serializer = TaskListSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        task = serializer.save()
        assert task.discipline == discipline

    def test_task_without_discipline(self):
        task = TaskFactory(discipline=None, area="work")
        data = TaskListSerializer(task).data
        assert data["discipline"] is None

    def test_discipline_set_null_on_delete(self):
        discipline = DisciplineFactory()
        task = TaskFactory(discipline=discipline)
        discipline.delete()
        task.refresh_from_db()
        assert task.discipline is None

    def test_task_detail_includes_discipline(self):
        discipline = DisciplineFactory()
        task = TaskFactory(discipline=discipline, area="study")
        data = TaskSerializer(task).data
        assert str(data["discipline"]) == str(discipline.pk)


@pytest.mark.django_db
class TestTaskReorderSerializer:
    def test_valid_item(self):
        import uuid

        data = {"id": str(uuid.uuid4()), "kanban_order": 0, "kanban_status": "todo"}
        serializer = TaskReorderSerializer(data=data)
        assert serializer.is_valid(), serializer.errors

    def test_invalid_kanban_status(self):
        import uuid

        data = {"id": str(uuid.uuid4()), "kanban_order": 0, "kanban_status": "invalid"}
        serializer = TaskReorderSerializer(data=data)
        assert not serializer.is_valid()
        assert "kanban_status" in serializer.errors

    def test_invalid_uuid(self):
        data = {"id": "not-a-uuid", "kanban_order": 0, "kanban_status": "todo"}
        serializer = TaskReorderSerializer(data=data)
        assert not serializer.is_valid()
        assert "id" in serializer.errors


@pytest.mark.django_db
class TestTimeBlockSerializerValidation:
    def test_end_time_must_be_after_start_time(self, task):
        data = {
            "task": str(task.id),
            "date": "2025-01-15",
            "start_time": "10:00:00",
            "end_time": "09:00:00",
        }
        serializer = TimeBlockSerializer(data=data)
        assert not serializer.is_valid()
        assert "non_field_errors" in serializer.errors

    def test_equal_times_invalid(self, task):
        data = {
            "task": str(task.id),
            "date": "2025-01-15",
            "start_time": "10:00:00",
            "end_time": "10:00:00",
        }
        serializer = TimeBlockSerializer(data=data)
        assert not serializer.is_valid()

    def test_valid_times_pass(self, task):
        data = {
            "task": str(task.id),
            "date": "2025-01-15",
            "start_time": "09:00:00",
            "end_time": "10:00:00",
        }
        serializer = TimeBlockSerializer(data=data)
        assert serializer.is_valid()

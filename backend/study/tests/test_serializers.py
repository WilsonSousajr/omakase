import datetime

import pytest
from django.db.models import Count

from conftest import (
    ClassScheduleFactory,
    DisciplineFactory,
    SemesterFactory,
    StudyBlockFactory,
)
from study.serializers import (
    ClassOccurrenceSerializer,
    ClassScheduleSerializer,
    DisciplineSerializer,
    SemesterSerializer,
    StudyBlockSerializer,
)


@pytest.mark.django_db
class TestSemesterSerializer:
    def test_valid_create(self):
        from conftest import UserFactory

        user = UserFactory()
        data = {
            "name": "Fall 2026",
            "institution": "MIT",
            "start_date": "2026-09-01",
            "end_date": "2026-12-20",
            "status": "active",
        }
        serializer = SemesterSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        semester = serializer.save(user=user)
        assert semester.name == "Fall 2026"
        assert semester.institution == "MIT"

    def test_end_date_must_be_after_start_date(self):
        data = {
            "name": "Bad Semester",
            "start_date": "2026-09-01",
            "end_date": "2026-01-01",
        }
        serializer = SemesterSerializer(data=data)
        assert not serializer.is_valid()
        assert "non_field_errors" in serializer.errors

    def test_equal_dates_invalid(self):
        data = {
            "name": "Same Day",
            "start_date": "2026-09-01",
            "end_date": "2026-09-01",
        }
        serializer = SemesterSerializer(data=data)
        assert not serializer.is_valid()

    def test_read_only_fields(self):
        semester = SemesterFactory()
        data = SemesterSerializer(semester).data
        assert "id" in data
        assert "created_at" in data
        assert "updated_at" in data

    def test_discipline_count_annotation(self):
        semester = SemesterFactory()
        DisciplineFactory(semester=semester)
        DisciplineFactory(semester=semester)
        annotated = (
            type(semester)
            .objects.filter(pk=semester.pk)
            .annotate(discipline_count=Count("disciplines"))
            .first()
        )
        data = SemesterSerializer(annotated).data
        assert data["discipline_count"] == 2

    def test_discipline_count_defaults_zero(self):
        semester = SemesterFactory()
        data = SemesterSerializer(semester).data
        assert data["discipline_count"] == 0

    def test_partial_update_validates_dates(self):
        semester = SemesterFactory(
            start_date=datetime.date(2026, 3, 1),
            end_date=datetime.date(2026, 7, 15),
        )
        serializer = SemesterSerializer(
            semester, data={"end_date": "2026-01-01"}, partial=True
        )
        assert not serializer.is_valid()


@pytest.mark.django_db
class TestDisciplineSerializer:
    def test_valid_create(self):
        semester = SemesterFactory()
        data = {
            "semester": str(semester.pk),
            "name": "Calculus II",
            "code": "MAT201",
            "color": "#ff6600",
        }
        serializer = DisciplineSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        discipline = serializer.save()
        assert discipline.name == "Calculus II"
        assert discipline.code == "MAT201"

    def test_study_block_count_annotation(self):
        discipline = DisciplineFactory()
        StudyBlockFactory(discipline=discipline)
        StudyBlockFactory(discipline=discipline)
        StudyBlockFactory(discipline=discipline)
        annotated = (
            type(discipline)
            .objects.filter(pk=discipline.pk)
            .annotate(study_block_count=Count("study_blocks"))
            .first()
        )
        data = DisciplineSerializer(annotated).data
        assert data["study_block_count"] == 3

    def test_study_block_count_defaults_zero(self):
        discipline = DisciplineFactory()
        data = DisciplineSerializer(discipline).data
        assert data["study_block_count"] == 0

    def test_optional_fields_blank(self):
        semester = SemesterFactory()
        data = {
            "semester": str(semester.pk),
            "name": "Physics",
        }
        serializer = DisciplineSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        discipline = serializer.save()
        assert discipline.professor == ""
        assert discipline.credits is None
        assert discipline.target_grade is None


@pytest.mark.django_db
class TestStudyBlockSerializer:
    def test_valid_create(self):
        discipline = DisciplineFactory()
        data = {
            "discipline": str(discipline.pk),
            "title": "Chapter 5 — Integrals",
            "block_type": "theory",
            "priority": "high",
        }
        serializer = StudyBlockSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        block = serializer.save()
        assert block.title == "Chapter 5 — Integrals"
        assert block.status == "planned"

    def test_completed_at_is_read_only(self):
        discipline = DisciplineFactory()
        data = {
            "discipline": str(discipline.pk),
            "title": "Read-only test",
            "completed_at": "2026-01-01T00:00:00Z",
        }
        serializer = StudyBlockSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        block = serializer.save()
        assert block.completed_at is None

    def test_is_completed_syncs_status(self):
        block = StudyBlockFactory(is_completed=False)
        serializer = StudyBlockSerializer(
            block, data={"is_completed": True}, partial=True
        )
        assert serializer.is_valid(), serializer.errors
        updated = serializer.save()
        assert updated.status == "completed"
        assert updated.completed_at is not None

    def test_all_block_types_valid(self):
        discipline = DisciplineFactory()
        for block_type in [
            "theory", "exercises", "review", "assignment",
            "exam_prep", "lab", "reading",
        ]:
            data = {
                "discipline": str(discipline.pk),
                "title": f"Test {block_type}",
                "block_type": block_type,
            }
            serializer = StudyBlockSerializer(data=data)
            assert serializer.is_valid(), f"{block_type}: {serializer.errors}"


@pytest.mark.django_db
class TestClassScheduleSerializer:
    def test_valid_create(self):
        discipline = DisciplineFactory()
        data = {
            "discipline": str(discipline.pk),
            "day_of_week": 2,
            "start_time": "14:00:00",
            "end_time": "15:40:00",
            "class_type": "lecture",
            "location": "Auditorium B",
        }
        serializer = ClassScheduleSerializer(data=data)
        assert serializer.is_valid(), serializer.errors
        schedule = serializer.save()
        assert schedule.day_of_week == 2
        assert schedule.location == "Auditorium B"

    def test_end_time_must_be_after_start_time(self):
        discipline = DisciplineFactory()
        data = {
            "discipline": str(discipline.pk),
            "day_of_week": 0,
            "start_time": "14:00:00",
            "end_time": "13:00:00",
        }
        serializer = ClassScheduleSerializer(data=data)
        assert not serializer.is_valid()
        assert "non_field_errors" in serializer.errors

    def test_equal_times_invalid(self):
        discipline = DisciplineFactory()
        data = {
            "discipline": str(discipline.pk),
            "day_of_week": 0,
            "start_time": "10:00:00",
            "end_time": "10:00:00",
        }
        serializer = ClassScheduleSerializer(data=data)
        assert not serializer.is_valid()

    def test_read_only_fields(self):
        schedule = ClassScheduleFactory()
        data = ClassScheduleSerializer(schedule).data
        assert "id" in data
        assert "created_at" in data
        assert "updated_at" in data


class TestClassOccurrenceSerializer:
    def test_serializes_occurrence_shape(self):
        occurrence = {
            "id": "abc123-2026-03-05",
            "class_schedule_id": "abc123",
            "discipline_name": "Calculus II",
            "discipline_color": "#ff6600",
            "class_type": "lecture",
            "location": "Room 101",
            "date": datetime.date(2026, 3, 5),
            "start_time": datetime.time(10, 0),
            "end_time": datetime.time(11, 40),
        }
        serializer = ClassOccurrenceSerializer(occurrence)
        data = serializer.data
        assert data["id"] == "abc123-2026-03-05"
        assert data["discipline_name"] == "Calculus II"
        assert data["date"] == "2026-03-05"
        assert data["start_time"] == "10:00:00"

    def test_serializes_many(self):
        occurrences = [
            {
                "id": f"sched-2026-03-0{i}",
                "class_schedule_id": "sched",
                "discipline_name": "Physics",
                "discipline_color": "#333333",
                "class_type": "lab",
                "location": "Lab 2",
                "date": datetime.date(2026, 3, i),
                "start_time": datetime.time(14, 0),
                "end_time": datetime.time(16, 0),
            }
            for i in range(1, 4)
        ]
        serializer = ClassOccurrenceSerializer(occurrences, many=True)
        assert len(serializer.data) == 3

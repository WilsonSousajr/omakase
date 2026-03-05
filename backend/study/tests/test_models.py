import datetime

import pytest
from django.db import IntegrityError

from conftest import DisciplineFactory, SemesterFactory, StudyBlockFactory


@pytest.mark.django_db
class TestSemester:
    def test_str(self, semester):
        assert str(semester) == semester.name

    def test_ordering_by_start_date_desc(self, user):
        s1 = SemesterFactory(user=user, start_date=datetime.date(2025, 1, 1), end_date=datetime.date(2025, 6, 1))
        s2 = SemesterFactory(user=user, start_date=datetime.date(2026, 1, 1), end_date=datetime.date(2026, 6, 1))
        from study.models import Semester

        semesters = list(Semester.objects.filter(user=user))
        assert semesters[0] == s2
        assert semesters[1] == s1

    def test_end_before_start_raises_integrity_error(self, user):
        with pytest.raises(IntegrityError):
            SemesterFactory(
                user=user,
                start_date=datetime.date(2026, 6, 1),
                end_date=datetime.date(2026, 1, 1),
            )


@pytest.mark.django_db
class TestDiscipline:
    def test_str_with_code(self, discipline):
        assert discipline.code in str(discipline)
        assert discipline.name in str(discipline)

    def test_str_without_code(self, user):
        d = DisciplineFactory(semester__user=user, code="")
        assert str(d) == d.name

    def test_ordering_by_name(self, user):
        sem = SemesterFactory(user=user)
        d_b = DisciplineFactory(semester=sem, name="Beta")
        d_a = DisciplineFactory(semester=sem, name="Alpha")
        from study.models import Discipline

        disciplines = list(Discipline.objects.filter(semester=sem))
        assert disciplines[0] == d_a
        assert disciplines[1] == d_b


@pytest.mark.django_db
class TestStudyBlock:
    def test_str(self, study_block):
        assert str(study_block) == study_block.title

    def test_is_completed_syncs_status(self, user):
        sb = StudyBlockFactory(discipline__semester__user=user, is_completed=True)
        assert sb.status == "completed"
        assert sb.completed_at is not None

    def test_status_completed_syncs_is_completed(self, user):
        sb = StudyBlockFactory(discipline__semester__user=user)
        sb.status = "completed"
        sb.save()
        assert sb.is_completed is True
        assert sb.completed_at is not None

    def test_uncomplete_clears_timestamp(self, user):
        sb = StudyBlockFactory(discipline__semester__user=user, is_completed=True)
        sb.is_completed = False
        sb.save()
        assert sb.status == "planned"
        assert sb.completed_at is None

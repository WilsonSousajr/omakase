import datetime

import pytest
from rest_framework import status

from conftest import DisciplineFactory, SemesterFactory, StudyBlockFactory, TaskFactory, TimeBlockFactory


@pytest.mark.django_db
class TestSemesterViewSet:
    URL = "/api/v1/study/semesters/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_list_semesters(self, authenticated_client, user):
        SemesterFactory.create_batch(2, user=user)
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_list_scoped_to_user(self, authenticated_client, user):
        SemesterFactory.create_batch(2, user=user)
        SemesterFactory.create_batch(3)  # different user
        resp = authenticated_client.get(self.URL)
        assert resp.data["count"] == 2

    def test_create_semester(self, authenticated_client, user):
        resp = authenticated_client.post(
            self.URL,
            {
                "name": "2026.1",
                "institution": "UnB",
                "start_date": "2026-03-01",
                "end_date": "2026-07-15",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "2026.1"
        assert resp.data["discipline_count"] == 0

    def test_create_semester_invalid_dates(self, authenticated_client):
        resp = authenticated_client.post(
            self.URL,
            {
                "name": "Bad",
                "start_date": "2026-07-15",
                "end_date": "2026-03-01",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_retrieve_semester(self, authenticated_client, semester):
        resp = authenticated_client.get(f"{self.URL}{semester.pk}/")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["id"] == str(semester.pk)

    def test_update_semester(self, authenticated_client, semester):
        resp = authenticated_client.patch(
            f"{self.URL}{semester.pk}/",
            {"name": "Updated"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["name"] == "Updated"

    def test_delete_semester(self, authenticated_client, semester):
        resp = authenticated_client.delete(f"{self.URL}{semester.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_discipline_count_annotation(self, authenticated_client, user):
        sem = SemesterFactory(user=user)
        DisciplineFactory.create_batch(3, semester=sem)
        resp = authenticated_client.get(f"{self.URL}{sem.pk}/")
        assert resp.data["discipline_count"] == 3


@pytest.mark.django_db
class TestDisciplineViewSet:
    URL = "/api/v1/study/disciplines/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_list_disciplines(self, authenticated_client, user):
        sem = SemesterFactory(user=user)
        DisciplineFactory.create_batch(2, semester=sem)
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

    def test_list_scoped_to_user(self, authenticated_client, user):
        sem = SemesterFactory(user=user)
        DisciplineFactory.create_batch(2, semester=sem)
        DisciplineFactory.create_batch(3)  # different user
        resp = authenticated_client.get(self.URL)
        assert resp.data["count"] == 2

    def test_filter_by_semester(self, authenticated_client, user):
        sem1 = SemesterFactory(user=user)
        sem2 = SemesterFactory(user=user)
        DisciplineFactory.create_batch(2, semester=sem1)
        DisciplineFactory(semester=sem2)
        resp = authenticated_client.get(f"{self.URL}?semester={sem1.pk}")
        assert resp.data["count"] == 2

    def test_create_discipline(self, authenticated_client, user):
        sem = SemesterFactory(user=user)
        resp = authenticated_client.post(
            self.URL,
            {
                "semester": str(sem.pk),
                "name": "Calculo 2",
                "code": "MAT0026",
                "professor": "Dr. Silva",
                "color": "#6366f1",
                "credits": 6,
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["name"] == "Calculo 2"
        assert resp.data["study_block_count"] == 0

    def test_retrieve_discipline(self, authenticated_client, discipline):
        resp = authenticated_client.get(f"{self.URL}{discipline.pk}/")
        assert resp.status_code == status.HTTP_200_OK

    def test_delete_discipline(self, authenticated_client, discipline):
        resp = authenticated_client.delete(f"{self.URL}{discipline.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT

    def test_study_block_count_annotation(self, authenticated_client, user):
        disc = DisciplineFactory(semester__user=user)
        StudyBlockFactory.create_batch(5, discipline=disc)
        resp = authenticated_client.get(f"{self.URL}{disc.pk}/")
        assert resp.data["study_block_count"] == 5


@pytest.mark.django_db
class TestStudyBlockViewSet:
    URL = "/api/v1/study/studyblocks/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_list_study_blocks(self, authenticated_client, user):
        disc = DisciplineFactory(semester__user=user)
        StudyBlockFactory.create_batch(3, discipline=disc)
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 3

    def test_list_scoped_to_user(self, authenticated_client, user):
        disc = DisciplineFactory(semester__user=user)
        StudyBlockFactory.create_batch(2, discipline=disc)
        StudyBlockFactory.create_batch(3)  # different user
        resp = authenticated_client.get(self.URL)
        assert resp.data["count"] == 2

    def test_filter_by_discipline(self, authenticated_client, user):
        disc1 = DisciplineFactory(semester__user=user)
        disc2 = DisciplineFactory(semester__user=user)
        StudyBlockFactory.create_batch(2, discipline=disc1)
        StudyBlockFactory(discipline=disc2)
        resp = authenticated_client.get(f"{self.URL}?discipline={disc1.pk}")
        assert resp.data["count"] == 2

    def test_filter_by_block_type(self, authenticated_client, user):
        disc = DisciplineFactory(semester__user=user)
        StudyBlockFactory(discipline=disc, block_type="theory")
        StudyBlockFactory(discipline=disc, block_type="exercises")
        resp = authenticated_client.get(f"{self.URL}?block_type=theory")
        assert resp.data["count"] == 1

    def test_create_study_block(self, authenticated_client, user):
        disc = DisciplineFactory(semester__user=user)
        resp = authenticated_client.post(
            self.URL,
            {
                "discipline": str(disc.pk),
                "title": "Chapter 5 exercises",
                "block_type": "exercises",
                "priority": "high",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["title"] == "Chapter 5 exercises"
        assert resp.data["block_type"] == "exercises"
        assert resp.data["status"] == "planned"

    def test_retrieve_study_block(self, authenticated_client, study_block):
        resp = authenticated_client.get(f"{self.URL}{study_block.pk}/")
        assert resp.status_code == status.HTTP_200_OK

    def test_complete_study_block(self, authenticated_client, study_block):
        resp = authenticated_client.patch(
            f"{self.URL}{study_block.pk}/",
            {"is_completed": True},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["is_completed"] is True
        assert resp.data["status"] == "completed"
        assert resp.data["completed_at"] is not None

    def test_delete_study_block(self, authenticated_client, study_block):
        resp = authenticated_client.delete(f"{self.URL}{study_block.pk}/")
        assert resp.status_code == status.HTTP_204_NO_CONTENT


@pytest.mark.django_db
class TestTimeBlockPolymorphicFK:
    URL = "/api/v1/timeblocks/"

    def test_create_timeblock_with_task(self, authenticated_client, user):
        task = TaskFactory(user=user)
        resp = authenticated_client.post(
            self.URL,
            {
                "task": str(task.pk),
                "date": "2026-03-04",
                "start_time": "09:00",
                "end_time": "10:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["task"] == str(task.pk)
        assert resp.data["study_block"] is None

    def test_create_timeblock_with_study_block(self, authenticated_client, user):
        sb = StudyBlockFactory(discipline__semester__user=user)
        resp = authenticated_client.post(
            self.URL,
            {
                "study_block": str(sb.pk),
                "date": "2026-03-04",
                "start_time": "10:00",
                "end_time": "11:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["study_block"] == str(sb.pk)
        assert resp.data["task"] is None

    def test_create_timeblock_without_either_fails(self, authenticated_client):
        resp = authenticated_client.post(
            self.URL,
            {
                "date": "2026-03-04",
                "start_time": "09:00",
                "end_time": "10:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_create_timeblock_with_both_fails(self, authenticated_client, user):
        task = TaskFactory(user=user)
        sb = StudyBlockFactory(discipline__semester__user=user)
        resp = authenticated_client.post(
            self.URL,
            {
                "task": str(task.pk),
                "study_block": str(sb.pk),
                "date": "2026-03-04",
                "start_time": "09:00",
                "end_time": "10:00",
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_list_timeblocks_includes_study_blocks(self, authenticated_client, user):
        task = TaskFactory(user=user)
        sb = StudyBlockFactory(discipline__semester__user=user)
        TimeBlockFactory(task=task, study_block=None)
        TimeBlockFactory(task=None, study_block=sb, date=datetime.date(2026, 3, 5))
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2

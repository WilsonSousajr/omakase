from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import viewsets

from .models import Discipline, Semester, StudyBlock
from .serializers import DisciplineSerializer, SemesterSerializer, StudyBlockSerializer


class SemesterViewSet(viewsets.ModelViewSet):
    serializer_class = SemesterSerializer

    def get_queryset(self):
        return (
            Semester.objects.filter(user=self.request.user)
            .annotate(discipline_count=Count("disciplines"))
            .order_by("-start_date")
        )

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class DisciplineFilter(filters.FilterSet):
    class Meta:
        model = Discipline
        fields = ["semester", "status"]


class DisciplineViewSet(viewsets.ModelViewSet):
    serializer_class = DisciplineSerializer
    filterset_class = DisciplineFilter

    def get_queryset(self):
        return (
            Discipline.objects.filter(semester__user=self.request.user)
            .annotate(study_block_count=Count("study_blocks"))
            .order_by("name")
        )

    def perform_create(self, serializer):
        serializer.save()


class StudyBlockFilter(filters.FilterSet):
    class Meta:
        model = StudyBlock
        fields = ["discipline", "block_type", "status", "is_completed", "scheduled_date"]


class StudyBlockViewSet(viewsets.ModelViewSet):
    serializer_class = StudyBlockSerializer
    filterset_class = StudyBlockFilter

    def get_queryset(self):
        return StudyBlock.objects.filter(discipline__semester__user=self.request.user).select_related("discipline")

    def perform_create(self, serializer):
        serializer.save()

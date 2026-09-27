from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from omakase.client_dates import parse_client_date

from .models import ClassSchedule, Discipline, Holiday, Semester, StudyBlock
from .serializers import (
    ClassOccurrenceSerializer,
    ClassScheduleSerializer,
    DisciplineSerializer,
    HolidaySerializer,
    SemesterSerializer,
    StudyBlockSerializer,
)
from .services import class_occurrences


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
        semester = serializer.validated_data.get("semester")
        if semester and semester.user != self.request.user:
            raise PermissionDenied("You do not own this semester.")
        serializer.save()

    def perform_update(self, serializer):
        semester = serializer.validated_data.get("semester")
        if semester and semester.user != self.request.user:
            raise PermissionDenied("You do not own this semester.")
        serializer.save()


class StudyBlockFilter(filters.FilterSet):
    class Meta:
        model = StudyBlock
        fields = ["discipline", "block_type", "status", "is_completed", "scheduled_date"]


class StudyBlockViewSet(viewsets.ModelViewSet):
    serializer_class = StudyBlockSerializer
    filterset_class = StudyBlockFilter

    def get_queryset(self):
        return (
            StudyBlock.objects.filter(discipline__semester__user=self.request.user)
            .select_related("discipline")
            .prefetch_related("time_blocks")
        )

    def perform_create(self, serializer):
        discipline = serializer.validated_data.get("discipline")
        if discipline and discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this discipline.")
        serializer.save()

    def perform_update(self, serializer):
        discipline = serializer.validated_data.get("discipline")
        if discipline and discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this discipline.")
        serializer.save()

    @action(detail=False, methods=["get"], url_path="carried-over")
    def carried_over(self, request):
        target_date = parse_client_date(request.query_params.get("date"))
        blocks = self.get_queryset().filter(scheduled_date__lt=target_date).exclude(status__in=["completed", "skipped"])
        serializer = self.get_serializer(blocks, many=True)
        return Response(serializer.data)


class ClassScheduleFilter(filters.FilterSet):
    class Meta:
        model = ClassSchedule
        fields = ["discipline", "class_type", "is_active"]


class ClassScheduleViewSet(viewsets.ModelViewSet):
    serializer_class = ClassScheduleSerializer
    filterset_class = ClassScheduleFilter

    def get_queryset(self):
        return ClassSchedule.objects.filter(discipline__semester__user=self.request.user).select_related("discipline")

    def perform_create(self, serializer):
        discipline = serializer.validated_data.get("discipline")
        if discipline and discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this discipline.")
        serializer.save()

    def perform_update(self, serializer):
        discipline = serializer.validated_data.get("discipline")
        if discipline and discipline.semester.user != self.request.user:
            raise PermissionDenied("You do not own this discipline.")
        serializer.save()


class HolidayFilter(filters.FilterSet):
    class Meta:
        model = Holiday
        fields = ["semester"]


class HolidayViewSet(viewsets.ModelViewSet):
    """A semester's holidays (#125), scoped through the semester's owner."""

    serializer_class = HolidaySerializer
    filterset_class = HolidayFilter

    def get_queryset(self):
        return Holiday.objects.filter(semester__user=self.request.user).order_by("start_date")

    def perform_create(self, serializer):
        self._check_semester_owner(serializer)
        serializer.save()

    def perform_update(self, serializer):
        self._check_semester_owner(serializer)
        serializer.save()

    def _check_semester_owner(self, serializer) -> None:
        semester = serializer.validated_data.get("semester")
        if semester and semester.user != self.request.user:
            raise PermissionDenied("You do not own this semester.")


class ClassOccurrenceView(APIView):
    """Compute virtual class occurrences for a date range."""

    def get(self, request):
        start = parse_client_date(request.query_params.get("date_from"), name="date_from")
        end = parse_client_date(request.query_params.get("date_to"), name="date_to")

        if end < start:
            return Response(
                {"detail": "date_to must be >= date_from."},
                status=400,
            )

        # Cap range to 90 days to prevent abuse
        if (end - start).days > 90:
            return Response(
                {"detail": "Date range cannot exceed 90 days."},
                status=400,
            )

        occurrences = class_occurrences(request.user, start, end)
        serializer = ClassOccurrenceSerializer(occurrences, many=True)
        return Response(serializer.data)

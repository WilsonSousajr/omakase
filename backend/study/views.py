import datetime

from django.db.models import Count
from django_filters import rest_framework as filters
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ClassSchedule, Discipline, Semester, StudyBlock
from .serializers import (
    ClassOccurrenceSerializer,
    ClassScheduleSerializer,
    DisciplineSerializer,
    SemesterSerializer,
    StudyBlockSerializer,
)


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
        date_str = request.query_params.get("date")
        if not date_str:
            return Response(
                {"detail": "date param required."},
                status=400,
            )
        try:
            target_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            return Response(
                {"detail": "Invalid date format."},
                status=400,
            )
        blocks = (
            self.get_queryset()
            .filter(scheduled_date__lt=target_date)
            .exclude(status__in=["completed", "skipped"])
        )
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


class ClassOccurrenceView(APIView):
    """Compute virtual class occurrences for a date range."""

    def get(self, request):
        date_from = request.query_params.get("date_from")
        date_to = request.query_params.get("date_to")

        if not date_from or not date_to:
            return Response(
                {"detail": "date_from and date_to query parameters are required."},
                status=400,
            )

        try:
            start = datetime.date.fromisoformat(date_from)
            end = datetime.date.fromisoformat(date_to)
        except ValueError:
            return Response(
                {"detail": "Invalid date format. Use YYYY-MM-DD."},
                status=400,
            )

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

        schedules = ClassSchedule.objects.filter(
            discipline__semester__user=request.user,
            is_active=True,
        ).select_related("discipline")

        occurrences = []
        for schedule in schedules:
            # Only generate occurrences within the semester's date range
            semester = schedule.discipline.semester
            effective_start = max(start, semester.start_date)
            effective_end = min(end, semester.end_date)

            if effective_start > effective_end:
                continue

            # Walk days in range, find matching day_of_week
            current = effective_start
            while current <= effective_end:
                if current.weekday() == schedule.day_of_week:
                    occurrences.append(
                        {
                            "id": f"{schedule.id}-{current.isoformat()}",
                            "class_schedule_id": schedule.id,
                            "discipline_name": schedule.discipline.name,
                            "discipline_color": schedule.discipline.color,
                            "class_type": schedule.class_type,
                            "location": schedule.location,
                            "date": current,
                            "start_time": schedule.start_time,
                            "end_time": schedule.end_time,
                        }
                    )
                current += datetime.timedelta(days=1)

        serializer = ClassOccurrenceSerializer(occurrences, many=True)
        return Response(serializer.data)

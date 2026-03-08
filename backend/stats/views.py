import datetime

from django.db.models import DurationField, ExpressionWrapper, F, Q, Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from pomodoro.models import PomodoroSession
from study.models import StudyBlock
from tasks.models import Task, TimeBlock

from .models import DailyReview
from .serializers import DailyReviewSerializer


class DailyStatsView(APIView):
    def get(self, request):
        user = request.user
        date_str = request.query_params.get("date")
        if date_str:
            try:
                today = datetime.date.fromisoformat(date_str)
            except ValueError:
                today = timezone.localdate()
        else:
            today = timezone.localdate()
        week_start = today - datetime.timedelta(days=today.weekday())

        hours_focused_today = self._hours_focused_today(user, today)
        blocks_completed, blocks_total = self._blocks_today(user, today)
        current_streak = self._current_streak(user, today)
        weekly_work_hours = self._weekly_hours_by_area(user, week_start, today, "work")
        weekly_study_hours = self._weekly_hours_by_area(user, week_start, today, "study")

        return Response(
            {
                "hours_focused_today": hours_focused_today,
                "blocks_completed_today": blocks_completed,
                "blocks_total_today": blocks_total,
                "current_streak": current_streak,
                "weekly_work_hours": weekly_work_hours,
                "weekly_study_hours": weekly_study_hours,
            }
        )

    def _hours_focused_today(self, user, today):
        """Sum duration_minutes from completed focus PomodoroSessions today."""
        total = PomodoroSession.objects.filter(
            user=user,
            session_type="focus",
            completed=True,
            started_at__date=today,
        ).aggregate(total=Coalesce(Sum("duration_minutes"), 0))["total"]
        return round(total / 60, 1)

    def _blocks_today(self, user, today):
        """Count TimeBlocks for today. Completed = linked task/study_block is_completed."""
        user_filter = Q(task__user=user) | Q(study_block__discipline__semester__user=user)
        blocks = TimeBlock.objects.filter(user_filter, date=today).select_related("task", "study_block")
        total = blocks.count()
        completed = blocks.filter(Q(task__is_completed=True) | Q(study_block__is_completed=True)).count()
        return completed, total

    def _current_streak(self, user, today):
        """Count consecutive days backward with at least 1 completed TimeBlock."""
        dates = (
            TimeBlock.objects.filter(
                Q(task__user=user, task__is_completed=True)
                | Q(study_block__discipline__semester__user=user, study_block__is_completed=True),
            )
            .values_list("date", flat=True)
            .distinct()
            .order_by("-date")
        )
        streak = 0
        day = today
        for d in dates:
            if d == day:
                streak += 1
                day -= datetime.timedelta(days=1)
            elif d < day:
                # Gap found — streak is broken
                break
        return streak

    def _weekly_hours_by_area(self, user, week_start, today, area):
        """Sum TimeBlock durations this week for a given task/study area."""
        date_filter = Q(date__gte=week_start, date__lte=today)
        if area == "study":
            area_filter = Q(study_block__discipline__semester__user=user) | Q(task__user=user, task__area="study")
        else:
            area_filter = Q(task__user=user, task__area=area)
        total_duration = (
            TimeBlock.objects.filter(date_filter & area_filter)
            .annotate(
                duration=ExpressionWrapper(
                    F("end_time") - F("start_time"),
                    output_field=DurationField(),
                )
            )
            .aggregate(total=Coalesce(Sum("duration"), datetime.timedelta()))["total"]
        )
        total_minutes = total_duration.total_seconds() / 60
        return round(total_minutes / 60, 1)


class ReviewSummaryView(APIView):
    """Aggregate review data for a given date."""

    def get(self, request):
        date_str = request.query_params.get("date")
        if not date_str:
            return Response(
                {"detail": "date query parameter is required."},
                status=400,
            )

        try:
            review_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            return Response(
                {"detail": "Invalid date format. Use YYYY-MM-DD."},
                status=400,
            )

        user = request.user

        hours_focused = self._hours_focused(user, review_date)

        user_filter = Q(task__user=user) | Q(study_block__discipline__semester__user=user)
        blocks = TimeBlock.objects.filter(user_filter, date=review_date).select_related("task", "study_block")
        blocks_total = blocks.count()
        blocks_completed = blocks.filter(Q(task__is_completed=True) | Q(study_block__is_completed=True)).count()

        incomplete_tasks = Task.objects.filter(
            user=user,
            scheduled_date=review_date,
            is_completed=False,
        ).values("id", "title", "priority", "area", "estimated_minutes")

        incomplete_study_blocks = StudyBlock.objects.filter(
            discipline__semester__user=user,
            scheduled_date=review_date,
            is_completed=False,
        ).values("id", "title", "block_type", "priority", "estimated_minutes")

        completed_items_map = {}
        for block in blocks:
            is_task = block.task is not None
            linked = block.task if is_task else block.study_block
            if not linked:
                continue
            if not linked.is_completed:
                continue
            start = datetime.datetime.combine(block.date, block.start_time)
            end = datetime.datetime.combine(block.date, block.end_time)
            actual_min = int((end - start).total_seconds() / 60)
            item_id = str(linked.id)
            if item_id in completed_items_map:
                completed_items_map[item_id]["actual_minutes"] += actual_min
            else:
                completed_items_map[item_id] = {
                    "id": item_id,
                    "title": linked.title,
                    "type": "task" if is_task else "studyblock",
                    "estimated_minutes": linked.estimated_minutes,
                    "actual_minutes": actual_min,
                }
        completed_items = list(completed_items_map.values())

        daily_review = DailyReview.objects.filter(user=user, date=review_date).first()
        review_data = DailyReviewSerializer(daily_review).data if daily_review else None

        return Response(
            {
                "date": review_date.isoformat(),
                "hours_focused": hours_focused,
                "blocks_completed": blocks_completed,
                "blocks_total": blocks_total,
                "incomplete_tasks": list(incomplete_tasks),
                "incomplete_study_blocks": list(incomplete_study_blocks),
                "completed_items": completed_items,
                "daily_review": review_data,
            }
        )

    def _hours_focused(self, user, date):
        total = PomodoroSession.objects.filter(
            user=user,
            session_type="focus",
            completed=True,
            started_at__date=date,
        ).aggregate(total=Coalesce(Sum("duration_minutes"), 0))["total"]
        return round(total / 60, 1)


class DailyReviewViewSet(viewsets.ModelViewSet):
    serializer_class = DailyReviewSerializer
    filterset_fields = ["date"]

    def get_queryset(self):
        return DailyReview.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        instance = serializer.instance
        if serializer.validated_data.get("is_shutdown") and not instance.is_shutdown:
            serializer.save(shutdown_at=timezone.now())
        elif instance.is_shutdown and serializer.validated_data.get("is_shutdown") is False:
            serializer.save(shutdown_at=None)
        else:
            serializer.save()

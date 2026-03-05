import datetime

from django.db.models import Sum
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from pomodoro.models import PomodoroSession
from tasks.models import TimeBlock


class DailyStatsView(APIView):
    def get(self, request):
        user = request.user
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
        total = (
            PomodoroSession.objects.filter(
                user=user,
                session_type="focus",
                completed=True,
                started_at__date=today,
            )
            .aggregate(total=Coalesce(Sum("duration_minutes"), 0))["total"]
        )
        return round(total / 60, 1)

    def _blocks_today(self, user, today):
        """Count TimeBlocks for today. Completed = linked task is_completed."""
        blocks = TimeBlock.objects.filter(task__user=user, date=today).select_related("task")
        total = blocks.count()
        completed = blocks.filter(task__is_completed=True).count()
        return completed, total

    def _current_streak(self, user, today):
        """Count consecutive days backward with at least 1 completed TimeBlock."""
        streak = 0
        day = today
        while True:
            has_completed = TimeBlock.objects.filter(
                task__user=user,
                date=day,
                task__is_completed=True,
            ).exists()
            if not has_completed:
                break
            streak += 1
            day -= datetime.timedelta(days=1)
        return streak

    def _weekly_hours_by_area(self, user, week_start, today, area):
        """Sum TimeBlock durations this week for a given task area."""
        blocks = TimeBlock.objects.filter(
            task__user=user,
            task__area=area,
            date__gte=week_start,
            date__lte=today,
        )
        total_minutes = 0
        for block in blocks:
            start = datetime.datetime.combine(block.date, block.start_time)
            end = datetime.datetime.combine(block.date, block.end_time)
            total_minutes += (end - start).total_seconds() / 60
        return round(total_minutes / 60, 1)

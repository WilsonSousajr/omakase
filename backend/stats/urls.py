from django.urls import path

from .views import DailyStatsView

urlpatterns = [
    path("daily/", DailyStatsView.as_view(), name="daily-stats"),
]

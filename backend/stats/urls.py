from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DailyReviewViewSet, DailyStatsView

router = DefaultRouter()
router.register(r"reviews", DailyReviewViewSet, basename="daily-review")

urlpatterns = [
    path("daily/", DailyStatsView.as_view(), name="daily-stats"),
    path("", include(router.urls)),
]

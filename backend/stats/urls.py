from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DailyReviewViewSet, DailyStatsView, ReviewSummaryView, WorkloadView

router = DefaultRouter()
router.register(r"reviews", DailyReviewViewSet, basename="daily-review")

urlpatterns = [
    path("daily/", DailyStatsView.as_view(), name="daily-stats"),
    path("review/", ReviewSummaryView.as_view(), name="review-summary"),
    path("workload/", WorkloadView.as_view(), name="workload"),
    path("", include(router.urls)),
]

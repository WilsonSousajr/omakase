from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import PomodoroSessionViewSet

router = DefaultRouter()
router.register("sessions", PomodoroSessionViewSet)

urlpatterns = [
    path("", include(router.urls)),
]

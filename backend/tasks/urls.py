from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import TagViewSet, TaskViewSet, TimeBlockViewSet

router = DefaultRouter()
router.register("tasks", TaskViewSet, basename="task")
router.register("tags", TagViewSet, basename="tag")
router.register("timeblocks", TimeBlockViewSet, basename="timeblock")

urlpatterns = [
    path("", include(router.urls)),
]

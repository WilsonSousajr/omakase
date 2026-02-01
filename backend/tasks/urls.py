from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import TagViewSet, TaskViewSet, TimeBlockViewSet

router = DefaultRouter()
router.register("tasks", TaskViewSet)
router.register("tags", TagViewSet)
router.register("timeblocks", TimeBlockViewSet)

urlpatterns = [
    path("", include(router.urls)),
]

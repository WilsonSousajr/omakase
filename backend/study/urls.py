from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DisciplineViewSet, SemesterViewSet, StudyBlockViewSet

router = DefaultRouter()
router.register("semesters", SemesterViewSet, basename="semester")
router.register("disciplines", DisciplineViewSet, basename="discipline")
router.register("studyblocks", StudyBlockViewSet, basename="studyblock")

urlpatterns = [
    path("", include(router.urls)),
]

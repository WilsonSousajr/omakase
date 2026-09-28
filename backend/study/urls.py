from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ClassOccurrenceView,
    ClassScheduleViewSet,
    DisciplineViewSet,
    HolidayViewSet,
    SemesterViewSet,
    StudyBlockViewSet,
)

router = DefaultRouter()
router.register("semesters", SemesterViewSet, basename="semester")
router.register("disciplines", DisciplineViewSet, basename="discipline")
router.register("studyblocks", StudyBlockViewSet, basename="studyblock")
router.register("classschedules", ClassScheduleViewSet, basename="classschedule")
router.register("holidays", HolidayViewSet, basename="holiday")

urlpatterns = [
    path("class-occurrences/", ClassOccurrenceView.as_view(), name="class-occurrences"),
    path("", include(router.urls)),
]

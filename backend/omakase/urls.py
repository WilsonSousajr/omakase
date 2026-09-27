from django.contrib import admin
from django.urls import include, path

from omakase.health import health

urlpatterns = [
    path("admin/", admin.site.urls),
    # Outside api/v1: it is the platform's, not the clients' (#243).
    path("api/health/", health, name="health"),
    path("api/v1/auth/", include("accounts.urls")),
    path("api/v1/", include("tasks.urls")),
    path("api/v1/pomodoro/", include("pomodoro.urls")),
    path("api/v1/stats/", include("stats.urls")),
    path("api/v1/study/", include("study.urls")),
]

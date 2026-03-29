from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from accounts.views import GoogleLoginView, MeView, UserProfileView

urlpatterns = [
    path("google/", GoogleLoginView.as_view(), name="auth-google"),
    path("token/refresh/", TokenRefreshView.as_view(), name="auth-token-refresh"),
    path("me/", MeView.as_view(), name="auth-me"),
    path("profile/", UserProfileView.as_view(), name="user-profile"),
]

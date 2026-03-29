from unittest.mock import patch

import pytest
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken


@pytest.fixture
def api_client():
    return APIClient()


GOOGLE_VERIFY_PATH = "accounts.views.id_token.verify_oauth2_token"


def _google_idinfo(email="google@example.com", given_name="Google", family_name="User"):
    return {
        "iss": "accounts.google.com",
        "sub": "123456789",
        "email": email,
        "email_verified": True,
        "given_name": given_name,
        "family_name": family_name,
    }


# -- Google Login --------------------------------------------------------------


@pytest.mark.django_db
class TestGoogleLogin:
    URL = "/api/v1/auth/google/"

    def test_new_user_created(self, api_client):
        with patch(GOOGLE_VERIFY_PATH, return_value=_google_idinfo()):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        assert "access" in resp.data
        assert "refresh" in resp.data
        assert resp.data["user"]["email"] == "google@example.com"
        assert resp.data["user"]["first_name"] == "Google"
        assert resp.data["user"]["last_name"] == "User"
        assert User.objects.filter(email="google@example.com").exists()

    def test_existing_user_login(self, api_client, user):
        user.email = "existing@example.com"
        user.save()
        idinfo = _google_idinfo(email="existing@example.com")
        with patch(GOOGLE_VERIFY_PATH, return_value=idinfo):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["user"]["email"] == "existing@example.com"
        # No duplicate user created
        assert User.objects.filter(email="existing@example.com").count() == 1

    def test_backfills_name_on_existing_user(self, api_client, user):
        user.email = "blank@example.com"
        user.first_name = ""
        user.last_name = ""
        user.save()
        idinfo = _google_idinfo(email="blank@example.com", given_name="New", family_name="Name")
        with patch(GOOGLE_VERIFY_PATH, return_value=idinfo):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        user.refresh_from_db()
        assert user.first_name == "New"
        assert user.last_name == "Name"

    def test_no_overwrite_existing_name(self, api_client, user):
        user.email = "named@example.com"
        user.first_name = "Original"
        user.last_name = "Name"
        user.save()
        idinfo = _google_idinfo(email="named@example.com", given_name="Google", family_name="Override")
        with patch(GOOGLE_VERIFY_PATH, return_value=idinfo):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        user.refresh_from_db()
        assert user.first_name == "Original"
        assert user.last_name == "Name"

    def test_invalid_token(self, api_client):
        with patch(GOOGLE_VERIFY_PATH, side_effect=ValueError("Invalid token")):
            resp = api_client.post(self.URL, {"credential": "bad-token"})
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid Google token" in resp.data["detail"]

    def test_unverified_email(self, api_client):
        idinfo = _google_idinfo()
        idinfo["email_verified"] = False
        with patch(GOOGLE_VERIFY_PATH, return_value=idinfo):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED
        assert "not verified" in resp.data["detail"]

    def test_missing_credential(self, api_client):
        resp = api_client.post(self.URL, {})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "credential" in resp.data

    def test_username_collision(self, api_client):
        User.objects.create_user(username="google", email="other@example.com")
        idinfo = _google_idinfo(email="google@example.com")
        with patch(GOOGLE_VERIFY_PATH, return_value=idinfo):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        new_user = User.objects.get(email="google@example.com")
        assert new_user.username == "google1"

    def test_profile_auto_created(self, api_client):
        with patch(GOOGLE_VERIFY_PATH, return_value=_google_idinfo()):
            resp = api_client.post(self.URL, {"credential": "valid-token"})
        assert resp.status_code == status.HTTP_200_OK
        user = User.objects.get(email="google@example.com")
        assert hasattr(user, "profile")
        assert hasattr(user, "user_profile")


# -- Token Refresh -------------------------------------------------------------


@pytest.mark.django_db
class TestTokenRefresh:
    URL = "/api/v1/auth/token/refresh/"

    def test_token_refresh_success(self, api_client, user):
        refresh = RefreshToken.for_user(user)
        resp = api_client.post(self.URL, {"refresh": str(refresh)})
        assert resp.status_code == status.HTTP_200_OK
        assert "access" in resp.data

    def test_token_refresh_invalid(self, api_client):
        resp = api_client.post(self.URL, {"refresh": "invalidtoken"})
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# -- Me ------------------------------------------------------------------------


@pytest.mark.django_db
class TestMe:
    URL = "/api/v1/auth/me/"

    def test_me_authenticated(self, user):
        client = APIClient()
        token = RefreshToken.for_user(user)
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(token.access_token)}")
        resp = client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["username"] == user.username
        assert resp.data["email"] == user.email
        assert "id" in resp.data
        assert "date_joined" in resp.data

    def test_me_includes_profile_fields(self, authenticated_client):
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert "first_name" in resp.data
        assert "last_name" in resp.data
        assert "avatar_color" in resp.data
        assert resp.data["avatar_color"] == "#a3a3a3"

    def test_me_patch_profile(self, authenticated_client, user):
        resp = authenticated_client.patch(
            self.URL,
            {"first_name": "John", "last_name": "Doe", "avatar_color": "#ff5733"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["first_name"] == "John"
        assert resp.data["last_name"] == "Doe"
        assert resp.data["avatar_color"] == "#ff5733"

    def test_me_patch_email(self, authenticated_client):
        resp = authenticated_client.patch(
            self.URL,
            {"email": "newemail@example.com"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["email"] == "newemail@example.com"

    def test_me_patch_email_uniqueness(self, authenticated_client):
        User.objects.create_user(username="other", email="taken@example.com", password="pass12345")
        resp = authenticated_client.patch(
            self.URL,
            {"email": "taken@example.com"},
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "email" in resp.data

    def test_me_patch_invalid_avatar_color(self, authenticated_client):
        resp = authenticated_client.patch(
            self.URL,
            {"avatar_color": "notacolor"},
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "avatar_color" in resp.data

    def test_me_patch_username_not_writable(self, authenticated_client, user):
        resp = authenticated_client.patch(
            self.URL,
            {"first_name": "Test"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["username"] == user.username

    def test_me_patch_preserves_avatar_color(self, authenticated_client, user):
        """BUG-10 regression: PATCH without avatar_color must not reset it."""
        user.profile.avatar_color = "#ff5733"
        user.profile.save()
        resp = authenticated_client.patch(
            self.URL,
            {"first_name": "Updated"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["avatar_color"] == "#ff5733"

    def test_me_unauthenticated(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# -- UserProfile ---------------------------------------------------------------


@pytest.mark.django_db
class TestUserProfile:
    URL = "/api/v1/auth/profile/"

    def test_get_profile_returns_defaults(self, authenticated_client):
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["timezone"] == "UTC"
        assert resp.data["week_starts_on"] == "monday"
        assert resp.data["pomodoro_work_minutes"] == 25
        assert resp.data["pomodoro_short_break_minutes"] == 5
        assert resp.data["pomodoro_long_break_minutes"] == 15
        assert resp.data["pomodoros_before_long_break"] == 4
        assert float(resp.data["daily_work_goal_hours"]) == 8.0
        assert float(resp.data["daily_study_goal_hours"]) == 4.0
        assert "created_at" in resp.data
        assert "updated_at" in resp.data

    def test_patch_profile_updates_values(self, authenticated_client):
        resp = authenticated_client.patch(
            self.URL,
            {
                "pomodoro_work_minutes": 50,
                "timezone": "America/Sao_Paulo",
                "week_starts_on": "sunday",
                "daily_work_goal_hours": 6.5,
            },
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["pomodoro_work_minutes"] == 50
        assert resp.data["timezone"] == "America/Sao_Paulo"
        assert resp.data["week_starts_on"] == "sunday"
        assert float(resp.data["daily_work_goal_hours"]) == 6.5
        # Defaults unchanged
        assert resp.data["pomodoro_short_break_minutes"] == 5

    def test_profile_auto_created_for_new_google_user(self, api_client):
        """Google login creates user, post_save signal creates profile."""
        with patch(GOOGLE_VERIFY_PATH, return_value=_google_idinfo(email="profile@example.com")):
            resp = api_client.post("/api/v1/auth/google/", {"credential": "valid-token"})
        access = resp.data["access"]
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["timezone"] == "UTC"

    def test_profile_unauthenticated(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_profile_read_only_fields(self, authenticated_client):
        """created_at and updated_at should not be writable."""
        resp = authenticated_client.patch(
            self.URL,
            {"created_at": "2020-01-01T00:00:00Z"},
            format="json",
        )
        assert resp.status_code == status.HTTP_200_OK
        # created_at should NOT be the value we tried to set
        assert resp.data["created_at"] != "2020-01-01T00:00:00Z"

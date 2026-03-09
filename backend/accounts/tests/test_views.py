import pytest
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APIClient


@pytest.fixture
def api_client():
    return APIClient()


# ── Register ──────────────────────────────────────────────────────────


@pytest.mark.django_db
class TestRegister:
    URL = "/api/v1/auth/register/"

    def test_register_success(self, api_client):
        resp = api_client.post(
            self.URL,
            {
                "username": "newuser",
                "email": "new@example.com",
                "password": "strongpass123",
                "password_confirm": "strongpass123",
            },
        )
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["username"] == "newuser"
        assert resp.data["email"] == "new@example.com"
        assert "password" not in resp.data
        assert User.objects.filter(username="newuser").exists()

    def test_register_duplicate_username(self, api_client, user):
        resp = api_client.post(
            self.URL,
            {
                "username": user.username,
                "email": "different@example.com",
                "password": "strongpass123",
                "password_confirm": "strongpass123",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "username" in resp.data

    def test_register_duplicate_email(self, api_client, user):
        resp = api_client.post(
            self.URL,
            {
                "username": "uniqueuser",
                "email": user.email,
                "password": "strongpass123",
                "password_confirm": "strongpass123",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "email" in resp.data

    def test_register_password_mismatch(self, api_client):
        resp = api_client.post(
            self.URL,
            {
                "username": "newuser",
                "email": "new@example.com",
                "password": "strongpass123",
                "password_confirm": "differentpass",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "password_confirm" in resp.data

    def test_register_missing_fields(self, api_client):
        resp = api_client.post(self.URL, {})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "username" in resp.data
        assert "email" in resp.data
        assert "password" in resp.data

    def test_register_password_too_short(self, api_client):
        resp = api_client.post(
            self.URL,
            {
                "username": "newuser",
                "email": "new@example.com",
                "password": "short",
                "password_confirm": "short",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST


# ── Token Obtain ──────────────────────────────────────────────────────


@pytest.mark.django_db
class TestTokenObtain:
    URL = "/api/v1/auth/token/"

    def test_token_obtain_success(self, api_client, user):
        resp = api_client.post(
            self.URL,
            {"username": user.username, "password": "testpass123"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert "access" in resp.data
        assert "refresh" in resp.data

    def test_token_obtain_wrong_password(self, api_client, user):
        resp = api_client.post(
            self.URL,
            {"username": user.username, "password": "wrongpassword"},
        )
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_token_obtain_nonexistent_user(self, api_client):
        resp = api_client.post(
            self.URL,
            {"username": "nobody", "password": "nopass123"},
        )
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# ── Token Refresh ─────────────────────────────────────────────────────


@pytest.mark.django_db
class TestTokenRefresh:
    URL = "/api/v1/auth/token/refresh/"

    def test_token_refresh_success(self, api_client, user):
        token_resp = api_client.post(
            "/api/v1/auth/token/",
            {"username": user.username, "password": "testpass123"},
        )
        refresh = token_resp.data["refresh"]

        resp = api_client.post(self.URL, {"refresh": refresh})
        assert resp.status_code == status.HTTP_200_OK
        assert "access" in resp.data

    def test_token_refresh_invalid(self, api_client):
        resp = api_client.post(self.URL, {"refresh": "invalidtoken"})
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# ── Me ────────────────────────────────────────────────────────────────


@pytest.mark.django_db
class TestMe:
    URL = "/api/v1/auth/me/"

    def test_me_authenticated(self, api_client, user):
        token_resp = api_client.post(
            "/api/v1/auth/token/",
            {"username": user.username, "password": "testpass123"},
        )
        access = token_resp.data["access"]

        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["username"] == user.username
        assert resp.data["email"] == user.email
        assert "id" in resp.data
        assert "date_joined" in resp.data

    def test_me_unauthenticated(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# ── UserProfile ───────────────────────────────────────────────────────


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

    def test_profile_auto_created_on_registration(self, api_client):
        """Register a new user via API, then GET profile — should exist."""
        api_client.post(
            "/api/v1/auth/register/",
            {
                "username": "profileuser",
                "email": "profile@example.com",
                "password": "strongpass123",
                "password_confirm": "strongpass123",
            },
        )
        # Login
        token_resp = api_client.post(
            "/api/v1/auth/token/",
            {"username": "profileuser", "password": "strongpass123"},
        )
        access = token_resp.data["access"]
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

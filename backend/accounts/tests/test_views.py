import pytest
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken


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

    def test_register_rejects_common_password(self, api_client):
        """BUG-1 regression: AUTH_PASSWORD_VALIDATORS must reject common passwords."""
        resp = api_client.post(
            self.URL,
            {
                "username": "newuser",
                "email": "new@example.com",
                "password": "password1234",
                "password_confirm": "password1234",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "password" in resp.data

    def test_register_rejects_numeric_password(self, api_client):
        """BUG-1 regression: NumericPasswordValidator must reject all-digit passwords."""
        resp = api_client.post(
            self.URL,
            {
                "username": "newuser",
                "email": "new@example.com",
                "password": "12345678",
                "password_confirm": "12345678",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "password" in resp.data


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


# ── Change Password ──────────────────────────────────────────────────


@pytest.mark.django_db
class TestChangePassword:
    URL = "/api/v1/auth/change-password/"

    def test_change_password_success(self, authenticated_client, user):
        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["detail"] == "Password changed successfully."
        user.refresh_from_db()
        assert user.check_password("newpass12345")

    def test_change_password_wrong_old(self, authenticated_client):
        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "wrongpassword",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "old_password" in resp.data

    def test_change_password_mismatch(self, authenticated_client):
        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "different123",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "new_password_confirm" in resp.data

    def test_change_password_too_short(self, authenticated_client):
        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "short",
                "new_password_confirm": "short",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_change_password_rejects_common_password(self, authenticated_client):
        """BUG-1 regression: AUTH_PASSWORD_VALIDATORS must reject common passwords."""
        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "password1234",
                "new_password_confirm": "password1234",
            },
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "new_password" in resp.data

    def test_change_password_blacklists_tokens(self, authenticated_client, user):
        """BUG-2 regression: outstanding tokens must be blacklisted after password change."""
        # Create an outstanding token for the user
        RefreshToken.for_user(user)
        assert OutstandingToken.objects.filter(user=user).exists()

        resp = authenticated_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
        )
        assert resp.status_code == status.HTTP_200_OK
        # All outstanding tokens should now be blacklisted
        outstanding = OutstandingToken.objects.filter(user=user)
        for ot in outstanding:
            assert BlacklistedToken.objects.filter(token=ot).exists()

    def test_change_password_unauthenticated(self, api_client):
        resp = api_client.post(
            self.URL,
            {
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
        )
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

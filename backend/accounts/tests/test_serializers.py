import pytest
from django.contrib.auth.models import User
from rest_framework.test import APIRequestFactory

from accounts.serializers import (
    ChangePasswordSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)


def make_request(user):
    factory = APIRequestFactory()
    request = factory.get("/")
    request.user = user
    return request


@pytest.mark.django_db
class TestUserSerializer:
    def test_includes_profile_fields(self, user):
        serializer = UserSerializer(user)
        data = serializer.data
        assert "first_name" in data
        assert "last_name" in data
        assert "avatar_color" in data
        assert data["avatar_color"] == "#a3a3a3"

    def test_all_fields_read_only(self, user):
        serializer = UserSerializer(user)
        for field in serializer.fields.values():
            assert field.read_only


@pytest.mark.django_db
class TestUpdateProfileSerializer:
    def test_update_first_name(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"first_name": "John"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.refresh_from_db()
        assert user.first_name == "John"

    def test_update_last_name(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"last_name": "Doe"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.refresh_from_db()
        assert user.last_name == "Doe"

    def test_update_email(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"email": "newemail@example.com"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.refresh_from_db()
        assert user.email == "newemail@example.com"

    def test_email_uniqueness(self, user):
        other = User.objects.create_user(username="other", email="taken@example.com")
        # Profile auto-created by signal
        assert hasattr(other, "profile")

        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"email": "taken@example.com"},
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "email" in serializer.errors

    def test_email_same_as_current(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"email": user.email},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors

    def test_update_avatar_color(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"avatar_color": "#ff5733"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.profile.refresh_from_db()
        assert user.profile.avatar_color == "#ff5733"

    def test_invalid_avatar_color(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"avatar_color": "notacolor"},
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "avatar_color" in serializer.errors

    def test_partial_update(self, user):
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"first_name": "Only"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.refresh_from_db()
        assert user.first_name == "Only"
        assert user.last_name == ""

    def test_partial_update_preserves_avatar_color(self, user):
        """BUG-10 regression: PATCH without avatar_color must not reset it."""
        user.profile.avatar_color = "#ff5733"
        user.profile.save()
        request = make_request(user)
        serializer = UpdateProfileSerializer(
            data={"first_name": "Test"},
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.profile.refresh_from_db()
        assert user.profile.avatar_color == "#ff5733"


@pytest.mark.django_db
class TestChangePasswordSerializer:
    def test_change_password_success(self, user):
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
            context={"request": request},
        )
        assert serializer.is_valid(), serializer.errors
        serializer.save()
        user.refresh_from_db()
        assert user.check_password("newpass12345")

    def test_wrong_old_password(self, user):
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "wrongpassword",
                "new_password": "newpass12345",
                "new_password_confirm": "newpass12345",
            },
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "old_password" in serializer.errors

    def test_new_passwords_mismatch(self, user):
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "testpass123",
                "new_password": "newpass12345",
                "new_password_confirm": "different123",
            },
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "new_password_confirm" in serializer.errors

    def test_new_password_too_short(self, user):
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "testpass123",
                "new_password": "short",
                "new_password_confirm": "short",
            },
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "new_password" in serializer.errors

    def test_new_password_too_common(self, user):
        """BUG-1 regression: AUTH_PASSWORD_VALIDATORS must be enforced."""
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "testpass123",
                "new_password": "password1234",
                "new_password_confirm": "password1234",
            },
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "new_password" in serializer.errors

    def test_new_password_entirely_numeric(self, user):
        """BUG-1 regression: NumericPasswordValidator must reject all-digit passwords."""
        request = make_request(user)
        serializer = ChangePasswordSerializer(
            data={
                "old_password": "testpass123",
                "new_password": "12345678",
                "new_password_confirm": "12345678",
            },
            context={"request": request},
        )
        assert not serializer.is_valid()
        assert "new_password" in serializer.errors

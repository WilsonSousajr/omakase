import pytest
from django.core.exceptions import ValidationError

from accounts.models import DEFAULT_AVATAR_COLOR, Profile


@pytest.mark.django_db
class TestProfile:
    def test_profile_auto_created_on_user_creation(self, user):
        assert hasattr(user, "profile")
        assert isinstance(user.profile, Profile)

    def test_profile_default_avatar_color(self, user):
        assert user.profile.avatar_color == DEFAULT_AVATAR_COLOR

    def test_profile_custom_avatar_color(self, user):
        user.profile.avatar_color = "#ff5733"
        user.profile.full_clean()
        user.profile.save()
        user.profile.refresh_from_db()
        assert user.profile.avatar_color == "#ff5733"

    def test_profile_invalid_avatar_color(self, user):
        user.profile.avatar_color = "notacolor"
        with pytest.raises(ValidationError):
            user.profile.full_clean()

    def test_profile_invalid_hex_without_hash(self, user):
        user.profile.avatar_color = "ff5733"
        with pytest.raises(ValidationError):
            user.profile.full_clean()

    def test_profile_one_to_one_relationship(self, user):
        assert user.profile.user == user
        assert Profile.objects.filter(user=user).count() == 1

    def test_profile_str(self, user):
        assert str(user.profile) == f"Profile({user.username})"

    def test_profile_has_timestamps(self, user):
        assert user.profile.created_at is not None
        assert user.profile.updated_at is not None

"""The profile's reminder preferences (#127, M3.6 spec §1).

The server defines the reminders and each client schedules them, so a Mac
and an iPhone read the same heads-up and shutdown time.
"""

import pytest
from django.db import IntegrityError
from rest_framework import status

from accounts.models import UserProfile

URL = "/api/v1/auth/profile/"


@pytest.mark.django_db
class TestBlockReminderMinutes:
    def test_defaults_to_five_minutes(self, authenticated_client):
        resp = authenticated_client.get(URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["block_reminder_minutes"] == 5

    @pytest.mark.parametrize("minutes", [0, 121])
    def test_outside_one_to_120_is_a_400_naming_value_and_range(self, authenticated_client, minutes):
        resp = authenticated_client.patch(URL, {"block_reminder_minutes": minutes}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        message = str(resp.data["block_reminder_minutes"][0])
        assert str(minutes) in message
        assert "1" in message and "120" in message

    @pytest.mark.parametrize("minutes", [1, 30, 120])
    def test_inside_the_range_is_stored(self, authenticated_client, user, minutes):
        resp = authenticated_client.patch(URL, {"block_reminder_minutes": minutes}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["block_reminder_minutes"] == minutes
        assert UserProfile.objects.get(user=user).block_reminder_minutes == minutes

    def test_null_turns_the_heads_up_off(self, authenticated_client, user):
        resp = authenticated_client.patch(URL, {"block_reminder_minutes": None}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["block_reminder_minutes"] is None
        assert UserProfile.objects.get(user=user).block_reminder_minutes is None

    def test_the_database_rejects_what_the_serializer_would(self, user):
        profile = UserProfile.objects.get(user=user)
        profile.block_reminder_minutes = 121
        with pytest.raises(IntegrityError):
            profile.save()


@pytest.mark.django_db
class TestShutdownReminderTime:
    def test_defaults_to_off(self, authenticated_client):
        resp = authenticated_client.get(URL)
        assert resp.data["shutdown_reminder_time"] is None

    def test_a_time_of_day_round_trips(self, authenticated_client):
        resp = authenticated_client.patch(URL, {"shutdown_reminder_time": "21:30"}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["shutdown_reminder_time"] == "21:30:00"
        assert authenticated_client.get(URL).data["shutdown_reminder_time"] == "21:30:00"

    def test_null_turns_it_off_again(self, authenticated_client):
        authenticated_client.patch(URL, {"shutdown_reminder_time": "21:30"}, format="json")
        resp = authenticated_client.patch(URL, {"shutdown_reminder_time": None}, format="json")
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["shutdown_reminder_time"] is None

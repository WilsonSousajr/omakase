"""POST auth/logout/ revokes the refresh token (#223).

Without it a sign-out only dropped the tokens on the client, and a stolen
refresh token stayed good for its whole 7 days.
"""

import pytest
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken
from rest_framework_simplejwt.tokens import RefreshToken

from conftest import UserFactory

LOGOUT = "/api/v1/auth/logout/"
REFRESH = "/api/v1/auth/token/refresh/"


def _client_for(user) -> tuple[APIClient, str]:
    refresh = RefreshToken.for_user(user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.access_token}")
    return client, str(refresh)


@pytest.mark.django_db
class TestLogout:
    def test_logout_blacklists_the_refresh_token(self):
        client, refresh = _client_for(UserFactory())
        resp = client.post(LOGOUT, {"refresh": refresh}, format="json")
        assert resp.status_code == status.HTTP_205_RESET_CONTENT
        assert BlacklistedToken.objects.filter(token__token=refresh).exists()

    def test_blacklisted_refresh_token_no_longer_refreshes(self):
        client, refresh = _client_for(UserFactory())
        client.post(LOGOUT, {"refresh": refresh}, format="json")
        resp = APIClient().post(REFRESH, {"refresh": refresh}, format="json")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_second_logout_is_205(self):
        # A retry after a lost reply must not turn a finished sign-out into an error.
        client, refresh = _client_for(UserFactory())
        client.post(LOGOUT, {"refresh": refresh}, format="json")
        resp = client.post(LOGOUT, {"refresh": refresh}, format="json")
        assert resp.status_code == status.HTTP_205_RESET_CONTENT
        assert BlacklistedToken.objects.count() == 1

    def test_invalid_refresh_token_is_205(self):
        client, _ = _client_for(UserFactory())
        resp = client.post(LOGOUT, {"refresh": "not.a.jwt"}, format="json")
        assert resp.status_code == status.HTTP_205_RESET_CONTENT
        assert not BlacklistedToken.objects.exists()

    def test_missing_refresh_is_400_naming_the_field(self):
        client, _ = _client_for(UserFactory())
        resp = client.post(LOGOUT, {}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "refresh" in resp.data

    def test_anonymous_logout_is_401(self):
        refresh = str(RefreshToken.for_user(UserFactory()))
        resp = APIClient().post(LOGOUT, {"refresh": refresh}, format="json")
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED
        assert not BlacklistedToken.objects.exists()

    def test_another_users_refresh_token_is_not_revoked(self):
        client, _ = _client_for(UserFactory())
        _, theirs = _client_for(UserFactory())
        resp = client.post(LOGOUT, {"refresh": theirs}, format="json")
        assert resp.status_code == status.HTTP_205_RESET_CONTENT
        assert not BlacklistedToken.objects.exists()
        assert APIClient().post(REFRESH, {"refresh": theirs}, format="json").status_code == status.HTTP_200_OK

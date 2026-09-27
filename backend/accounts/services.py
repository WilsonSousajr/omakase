"""Account operations the views call (AGENTS.md: views are thin)."""

from django.contrib.auth.models import User
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken


def revoke_refresh_token(user: User, raw_token: str) -> bool:
    """Blacklist the caller's refresh token; True if this call revoked it (#223).

    An invalid, expired or already-blacklisted token, or another user's, is
    left alone and reported as False: logout is idempotent, and the answer
    must not tell the caller which of those it was.

    >>> revoke_refresh_token(request.user, request.data["refresh"])
    True
    """
    try:
        token = RefreshToken(raw_token)
    except TokenError:
        return False
    if str(token.payload.get(api_settings.USER_ID_CLAIM)) != str(user.pk):
        return False
    token.blacklist()
    return True

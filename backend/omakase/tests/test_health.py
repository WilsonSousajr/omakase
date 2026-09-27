from unittest.mock import patch

import pytest
from django.db import OperationalError

from omakase.settings import cors_allowed_origins


@pytest.mark.django_db
def test_health_is_ok_with_the_database_up_and_needs_no_token(api_client):
    response = api_client.get("/api/health/")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_health_is_503_when_the_database_does_not_answer(api_client):
    with patch("omakase.health.database_answers", return_value=False):
        response = api_client.get("/api/health/")
    assert response.status_code == 503
    assert response.json() == {"status": "unavailable"}


def test_a_database_error_is_no_answer():
    class FailingCursor:
        def __enter__(self):
            raise OperationalError("connection refused")

        def __exit__(self, *exc):
            return False

    class FailingConnection:
        def cursor(self):
            return FailingCursor()

    from omakase.health import database_answers

    assert database_answers(FailingConnection()) is False


def test_cors_allows_no_origin_unless_the_environment_names_one():
    assert cors_allowed_origins({}) == []


def test_cors_reads_the_named_origins():
    env = {"CORS_ALLOWED_ORIGINS": "https://a.example, https://b.example ,"}
    assert cors_allowed_origins(env) == ["https://a.example", "https://b.example"]


@pytest.mark.django_db
def test_health_is_not_redirected_to_https(api_client, settings):
    # The container's own health probe speaks plain HTTP inside the network;
    # a 301 to https://localhost:8000 would fail it (#243).
    settings.SECURE_SSL_REDIRECT = True
    assert api_client.get("/api/health/").status_code == 200
    assert api_client.get("/api/v1/auth/me/").status_code == 301

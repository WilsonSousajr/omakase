"""pomodoro/sessions/ listed by time and by block, for Plan's actual lane (#199)."""

import datetime

import pytest
from rest_framework import status
from rest_framework.exceptions import ParseError

from conftest import PomodoroSessionFactory, TaskFactory, TimeBlockFactory, UserFactory
from pomodoro.services import parse_client_instant

URL = "/api/v1/pomodoro/sessions/"
NAIVE_MESSAGE_SHAPE = "is not an ISO-8601 instant with an offset"


def _at(hour: int) -> datetime.datetime:
    return datetime.datetime(2026, 3, 7, hour, tzinfo=datetime.UTC)


def _session(user, hour: int, **fields):
    return PomodoroSessionFactory(task=TaskFactory(user=user), started_at=_at(hour), **fields)


def _ids(resp) -> list[str]:
    return [row["id"] for row in resp.data["results"]]


class TestParseClientInstant:
    def test_an_offset_is_kept(self):
        parsed = parse_client_instant("2026-03-07T07:00:00-03:00", "started_after")
        assert parsed == _at(10)

    def test_z_is_utc(self):
        assert parse_client_instant("2026-03-07T10:00:00Z", "started_after") == _at(10)

    @pytest.mark.parametrize("raw", ["2026-03-07T10:00", "2026-03-07", "yesterday", ""])
    def test_naive_or_malformed_names_the_value_and_the_shape(self, raw):
        with pytest.raises(ParseError) as caught:
            parse_client_instant(raw, "started_before")
        message = str(caught.value.detail)
        assert f"started_before {raw!r} {NAIVE_MESSAGE_SHAPE}" in message
        assert "2026-09-26T10:00:00-03:00" in message


@pytest.mark.django_db
class TestSessionRange:
    def test_after_is_inclusive_and_before_exclusive(self, authenticated_client, user):
        _session(user, 9)
        inside = _session(user, 10)
        _session(user, 11)
        resp = authenticated_client.get(
            URL, {"started_after": "2026-03-07T10:00:00Z", "started_before": "2026-03-07T11:00:00Z"}
        )
        assert resp.status_code == status.HTTP_200_OK, resp.data
        assert _ids(resp) == [str(inside.pk)]

    def test_the_offset_is_honoured(self, authenticated_client, user):
        _session(user, 9)
        later = _session(user, 10)
        # 07:00 at -03:00 is 10:00Z; read as naive UTC it would also match 09:00.
        resp = authenticated_client.get(URL, {"started_after": "2026-03-07T07:00:00-03:00"})
        assert _ids(resp) == [str(later.pk)]

    def test_a_naive_bound_is_a_400_naming_it(self, authenticated_client):
        resp = authenticated_client.get(URL, {"started_after": "2026-03-07T10:00"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "started_after '2026-03-07T10:00'" in resp.data["detail"]
        assert NAIVE_MESSAGE_SHAPE in resp.data["detail"]

    def test_a_malformed_before_is_a_400(self, authenticated_client):
        resp = authenticated_client.get(URL, {"started_before": "tomorrow"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "started_before 'tomorrow'" in resp.data["detail"]

    def test_the_range_is_scoped_to_the_user(self, authenticated_client, user):
        mine = _session(user, 10)
        _session(UserFactory(), 10)
        resp = authenticated_client.get(
            URL, {"started_after": "2026-03-07T00:00:00Z", "started_before": "2026-03-08T00:00:00Z"}
        )
        assert _ids(resp) == [str(mine.pk)]


@pytest.mark.django_db
class TestSessionsByBlock:
    def test_time_block_keeps_that_blocks_sessions(self, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user))
        tied = _session(user, 10, time_block=block)
        _session(user, 11, time_block=TimeBlockFactory(task=TaskFactory(user=user)))
        _session(user, 12)
        resp = authenticated_client.get(URL, {"time_block": str(block.pk)})
        assert _ids(resp) == [str(tied.pk)]

    def test_another_users_block_lists_nothing(self, authenticated_client):
        other = UserFactory()
        block = TimeBlockFactory(task=TaskFactory(user=other))
        _session(other, 10, time_block=block)
        resp = authenticated_client.get(URL, {"time_block": str(block.pk)})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 0

    def test_a_malformed_time_block_is_a_400(self, authenticated_client):
        resp = authenticated_client.get(URL, {"time_block": "not-a-uuid"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "time_block" in resp.data


@pytest.mark.django_db
def test_sessions_that_start_together_page_in_a_stable_order(authenticated_client, user):
    # Pagination needs a total order; started_at alone ties (invariant 4's reason).
    sessions = [_session(user, 10) for _ in range(3)]
    resp = authenticated_client.get(URL)
    assert _ids(resp) == sorted(str(s.pk) for s in sessions)

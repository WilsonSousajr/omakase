# M3.1 Data foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Mac app everything M3's screens read and write:
- the server accepts the Mac's pomodoro clock and the block a session worked
- the review takes `energy` and can be set idempotently by date
- today's tasks carry their subtasks
- the Swift side caches the whole day, and queues about ten kinds of write
  through one outbox

**Architecture:**
- **Backend:** four additive API changes, each pinned by tests and a contract
  fixture.
- **Swift:**
  - DTOs and `APIClient` calls for the day
  - SwiftData records and a `DaySync` that replaces `TodaySync`
  - the outbox extended with a `kind` per entry and one `OutboxHandler` per
    kind, looked up by the worker
- The retry, backoff, park and placeholder machinery from M1 is untouched.

**Tech Stack:**
- Backend: Django 5.2, DRF 3.17, pytest with factory-boy.
- Swift 6: SwiftData, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-26-m3-1-data-foundation-design.md` (#140).
**Parent spec:** `docs/superpowers/specs/2026-09-25-macos-client-design.md`.

## Global Constraints

- AGENTS.md applies throughout: TDD, atomic commits `type(#N): …`, and
  branches `type/<N>-<slug>` from `develop`.
- **Backend:**
  - functions 4-20 lines, views thin, logic in `<app>/services.py`
  - error messages carry the offending value and the expected shape
- **Swift:**
  - function body ≤ 20 lines, CC ≤ 10, nesting ≤ 2, file ≤ 500 lines, no
    `print`
  - identifier names ≥ 3 characters
  - OmakaseAPI and OmakaseStore coverage ≥ 90%
- **Invariants:**
  - 1: every new query scoped to `request.user`
  - 2: dates via `parse_client_date`
  - 3: a 400 is raised in the serializer before the DB can 500
  - 8: contract changes update their tests, their fixtures and
    `CHANGELOG.md` in the same commit
  - 9: `POST pomodoro/sessions/` keeps `IdempotentCreateMixin` first
- The apps stay independent (import-linter): `pomodoro` may not import
  `tasks`.
- The dependency rule is `OmakaseFeatures → OmakaseStore → OmakaseAPI`.
- **Gates:**
  - `scripts/gate.sh` (backend) and `apps/apple/gate.sh` (Apple) both exit
    0 before every PR. The Apple gate runs locally since #134.
  - Every changed endpoint is exercised against `docker-compose up` with a
    real JWT before its PR.
- **Contract fixtures:** regenerate with
  `docker-compose exec -e WRITE_CONTRACT_FIXTURES=1 backend pytest tools/tests/test_contract_fixtures.py`
  and commit them with the change.

## Review Focus

1. **The profile's goal hours are `DecimalField`s**, so DRF sends them as
   strings (`"4.0"`), not numbers. Expected: `ProfileDTO` decodes them and
   exposes doubles. Pinned in Task 5: `decodesDecimalGoalHoursAsStrings`.
2. **Rescheduling a task to the backlog** (`scheduled_date: null`). A
   synthesized `Encodable` leaves out nil, so the PATCH would change
   nothing. Expected: the body carries an explicit `"scheduled_date":null`.
   Pinned in Task 7: `reschedulingToBacklogSendsAnExplicitNull`.
3. **A focus session on a task captured offline** (still `local-…`).
   Expected: when the capture is accepted, the queued session's body is
   rewritten to the server id before it is sent. Pinned in Task 8:
   `aSessionOnACapturedTaskSendsTheServerID`.
4. **A refresh that straddles midnight.** Expected: all six requests of one
   refresh ask for the same day, computed once. Pinned in Task 6:
   `oneRefreshAsksForOneDay`.
5. **The review's PUT replayed after shutdown** (the outbox retries a write
   the server already applied). Expected: `shutdown_at` keeps the first
   stamp and is not moved to the replay's time. Pinned in Task 3:
   `test_replayed_shutdown_keeps_the_first_stamp`.

---

### Task 0: Issues

Create the seven issues from spec section 4. Each is labelled `M3`, its type
and its area, and is added to project 11. Record their numbers; the tasks
below refer to them as `$SESSIONS`, `$ENERGY`, `$REVIEW`, `$SUBTASKS`, `$DTOS`,
`$SYNC` and `$KINDS`.

- [ ] **Step 1: Create them.**

```bash
mk() { gh issue create --title "$1" --body "$2" --label "$3" --label M3 --label "$4" ${5:+--label "$5"} | grep -o '[0-9]*$'; }
SESSIONS=$(mk "feat(M3): sessions keep the Mac's started_at and record their block" "M3.1 spec §1.1; refs #129. started_at becomes writable (window: 5 min ahead, 8 days back), ended_at >= started_at, a nullable time_block FK owned by the user." feat area:pomodoro invariant)
ENERGY=$(mk "feat(M3): energy on the daily review" "M3.1 spec §1.2; the backend half of #130. DailyReview.energy, nullable 1-3, validated in the serializer, a DB check constraint as the safety net." feat area:stats)
REVIEW=$(mk "feat(M3): the review is set by date (PUT by-date)" "M3.1 spec §1.3. PUT stats/reviews/by-date/<date>/ creates or updates the day's review, idempotent by its natural key, for the outbox." feat area:stats invariant)
SUBTASKS=$(mk "feat(M3): subtasks embedded in today and carried-over" "M3.1 spec §1.4. tasks/today/ and tasks/carried-over/ gain read-only subtasks, prefetched, with a flat query count." feat area:tasks)
DTOS=$(mk "feat(M3): DTOs and API calls for the day" "M3.1 spec §2. Contract fixtures for the day's reads; Swift DTOs and APIClient calls." feat area:apple)
SYNC=$(mk "feat(M3): day records and DaySync" "M3.1 spec §2. SwiftData records for the day; DaySync replaces TodaySync, deletes dropped items, recomputes the day." feat area:apple)
KINDS=$(mk "feat(M3): outbox kinds and handlers" "M3.1 spec §3. OutboxEntry.kind, one OutboxHandler per kind, unknown kinds park; the writes M3 needs." feat area:apple)
echo "SESSIONS=$SESSIONS ENERGY=$ENERGY REVIEW=$REVIEW SUBTASKS=$SUBTASKS DTOS=$DTOS SYNC=$SYNC KINDS=$KINDS"
```

---

### Task 1: Sessions keep the Mac's clock and their block (`$SESSIONS`)

**Files:**
- Modify:
  - `backend/pomodoro/models.py` (`started_at` default; the `time_block` FK)
  - `backend/pomodoro/serializers.py`
  - `backend/pomodoro/views.py`
  - `backend/tools/tests/test_contract_fixtures.py`
  - `CHANGELOG.md`
- Create:
  - `backend/pomodoro/migrations/000N_session_client_clock_and_block.py` (generated)
  - `backend/pomodoro/services.py`
  - `backend/pomodoro/tests/test_client_clock.py`

**Interfaces:**
- Produces:
  - `POST pomodoro/sessions/` accepts `started_at` (ISO-8601; optional) and
    `time_block` (uuid; optional)
  - the response gains `time_block`
  - the fixture `apps/apple/Fixtures/pomodoro_session.json`
  - `pomodoro.services.time_block_owner(block) -> User`

**Why the check lives in the view:** a time block belongs to `task.user` or to
`study_block.discipline.semester.user` (ARCHITECTURE.md). A serializer
queryset would need `pomodoro` to import `tasks`, which the independence
contract forbids. The view therefore raises `PermissionDenied`, exactly as it
already does for `task`. This supersedes the spec's "the serializer refuses",
and the PR says so.

**Why the model changes:** `started_at` is `auto_now_add`, and Django
overwrites an `auto_now_add` field on every create, so a writable serializer
field alone would be ignored.

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$SESSIONS-session-client-clock develop`.

- [ ] **Step 2: Write the failing tests** in
  `backend/pomodoro/tests/test_client_clock.py`.

```python
import datetime

import pytest
from django.utils import timezone
from rest_framework import status

from conftest import DisciplineFactory, SemesterFactory, StudyBlockFactory, TaskFactory, TimeBlockFactory, UserFactory

URL = "/api/v1/pomodoro/sessions/"


def _post(client, **fields):
    return client.post(URL, {"session_type": "focus", "duration_minutes": 25, **fields}, format="json")


@pytest.mark.django_db
class TestSessionsKeepTheMacsClock:
    def test_a_client_started_at_is_stored_as_sent(self, authenticated_client):
        started = timezone.now() - datetime.timedelta(hours=3)
        resp = _post(authenticated_client, started_at=started.isoformat())
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["started_at"] == started.astimezone(datetime.UTC).isoformat().replace("+00:00", "Z")

    def test_started_at_with_an_offset_is_stored_in_utc(self, authenticated_client):
        local = (timezone.now() - datetime.timedelta(hours=1)).astimezone(datetime.timezone(datetime.timedelta(hours=2)))
        resp = _post(authenticated_client, started_at=local.isoformat())
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["started_at"].endswith("Z")

    def test_an_omitted_started_at_is_still_stamped(self, authenticated_client):
        resp = _post(authenticated_client)
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["started_at"] is not None

    def test_a_future_started_at_is_a_400_naming_it(self, authenticated_client):
        future = timezone.now() + datetime.timedelta(minutes=10)
        resp = _post(authenticated_client, started_at=future.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "in the future" in str(resp.data["started_at"])

    def test_a_started_at_older_than_eight_days_is_a_400(self, authenticated_client):
        old = timezone.now() - datetime.timedelta(days=9)
        resp = _post(authenticated_client, started_at=old.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "older than 8 days" in str(resp.data["started_at"])

    def test_ended_before_started_is_a_400_naming_both(self, authenticated_client):
        started = timezone.now() - datetime.timedelta(minutes=30)
        ended = started - datetime.timedelta(minutes=1)
        resp = _post(authenticated_client, started_at=started.isoformat(), ended_at=ended.isoformat())
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "is before started_at" in str(resp.data["ended_at"])


@pytest.mark.django_db
class TestSessionsRecordTheirBlock:
    def test_a_session_records_its_task_block(self, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user))
        resp = _post(authenticated_client, time_block=str(block.pk))
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert str(resp.data["time_block"]) == str(block.pk)

    def test_a_session_records_its_study_block(self, authenticated_client, user):
        semester = SemesterFactory(user=user)
        study = StudyBlockFactory(discipline=DisciplineFactory(semester=semester))
        block = TimeBlockFactory(task=None, study_block=study)
        resp = _post(authenticated_client, time_block=str(block.pk))
        assert resp.status_code == status.HTTP_201_CREATED, resp.data

    def test_another_users_block_is_refused(self, authenticated_client):
        # Invariant 1 needs two users: a one-user test cannot see the leak.
        stranger_block = TimeBlockFactory(task=TaskFactory(user=UserFactory()))
        resp = _post(authenticated_client, time_block=str(stranger_block.pk))
        assert resp.status_code == status.HTTP_403_FORBIDDEN
```

Also add one contract fixture test to `TestContractFixtures` in
`backend/tools/tests/test_contract_fixtures.py`:

```python
    def test_pomodoro_session_create(self, authenticated_client, user):
        block = TimeBlockFactory(task=TaskFactory(user=user, project=None, discipline=None))
        resp = authenticated_client.post(
            "/api/v1/pomodoro/sessions/",
            {
                "task": str(block.task.pk),
                "time_block": str(block.pk),
                "session_type": "focus",
                "duration_minutes": 25,
                "started_at": "2026-03-07T09:00:00Z",
                "ended_at": "2026-03-07T09:25:00Z",
                "completed": True,
            },
            format="json",
        )
        assert resp.status_code == 201, resp.content
        check_fixture("pomodoro_session", _body(resp))
```

(Import `TimeBlockFactory` next to `TagFactory, TaskFactory`. This test pins
dates far in the past, so freeze "now" to 2026-03-07 10:00 UTC with
`@patch("pomodoro.serializers.timezone.now", return_value=datetime.datetime(2026, 3, 7, 10, tzinfo=datetime.UTC))`
as a decorator.)

- [ ] **Step 3: Run them and read the failures.**
  `docker-compose exec backend pytest pomodoro/tests/test_client_clock.py -q`
  Expected, each for the bug's reason:
  - the `started_at` assertions fail, because the stored value is "now"
  - the window tests are 201s
  - `time_block` is an unknown field, so it is ignored

- [ ] **Step 4: Implement.**

`backend/pomodoro/models.py`: replace `started_at` and add `time_block`
after `task`.

```python
from django.utils import timezone
...
    time_block = models.ForeignKey(
        "tasks.TimeBlock", on_delete=models.SET_NULL, null=True, blank=True, related_name="pomodoro_sessions"
    )
    ...
    # The Mac's clock, not the server's: a session finished offline is posted
    # later and must keep when it ran (M3.1 spec §1.1). The default still
    # stamps a session sent without one.
    started_at = models.DateTimeField(default=timezone.now, db_index=True)
```

Run `docker-compose exec backend python manage.py makemigrations pomodoro -n session_client_clock_and_block`.

`backend/pomodoro/serializers.py`:

```python
import datetime

from django.utils import timezone
from rest_framework import serializers

from .models import PomodoroSession

# How far ahead a Mac's clock may run, and how old a queued session may be:
# the refresh token lives 7 days, so the outbox cannot hold anything older.
FUTURE_SKEW = datetime.timedelta(minutes=5)
MAX_AGE = datetime.timedelta(days=8)


class PomodoroSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PomodoroSession
        fields = [
            "id",
            "task",
            "time_block",
            "session_type",
            "duration_minutes",
            "started_at",
            "ended_at",
            "completed",
        ]
        read_only_fields = ["id"]
        extra_kwargs = {"started_at": {"required": False}}

    def validate_started_at(self, value: datetime.datetime) -> datetime.datetime:
        now = timezone.now()
        if value > now + FUTURE_SKEW:
            raise serializers.ValidationError(
                f"started_at {value.isoformat()} is in the future; expected at or before {now.isoformat()}"
            )
        if value < now - MAX_AGE:
            raise serializers.ValidationError(
                f"started_at {value.isoformat()} is older than 8 days; no queued session can be"
            )
        return value

    def validate(self, data: dict) -> dict:
        started = data.get("started_at", getattr(self.instance, "started_at", None))
        ended = data.get("ended_at", getattr(self.instance, "ended_at", None))
        if started and ended and ended < started:
            raise serializers.ValidationError(
                {"ended_at": f"ended_at {ended.isoformat()} is before started_at {started.isoformat()}"}
            )
        return data
```

`backend/pomodoro/services.py`:

```python
"""Ownership rules for sessions, reached through the hierarchy without
importing another app (the independence contract)."""


def time_block_owner(block):
    """The user a time block belongs to: its task's, or its study block's.

    >>> time_block_owner(block) == request.user
    """
    if block.task_id:
        return block.task.user
    return block.study_block.discipline.semester.user
```

`backend/pomodoro/views.py`: replace `perform_create` and add
`perform_update`, so both check ownership.

```python
from .services import time_block_owner
...
    def get_queryset(self):
        return PomodoroSession.objects.filter(user=self.request.user).select_related("task", "time_block")

    def perform_create(self, serializer):
        self._check_ownership(serializer)
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        self._check_ownership(serializer)
        serializer.save()

    def _check_ownership(self, serializer):
        task = serializer.validated_data.get("task")
        if task and task.user != self.request.user:
            raise PermissionDenied("You do not own this task.")
        block = serializer.validated_data.get("time_block")
        if block and time_block_owner(block) != self.request.user:
            raise PermissionDenied(f"You do not own time block {block.pk}.")
```

- [ ] **Step 5: Run the tests and watch them pass.** Run
  `docker-compose exec backend pytest pomodoro/ -q`, then regenerate the
  fixtures (Global Constraints). `pomodoro_session.json` appears, and no
  other fixture changes.

- [ ] **Step 6: CHANGELOG.** Under `## [Unreleased]` → `### Changed`, add:
  `- \`POST pomodoro/sessions/\` accepts the client's \`started_at\` (5 min ahead to 8 days back) and a \`time_block\`; \`ended_at\` must not precede it (#$SESSIONS).`

- [ ] **Step 7: The gate and the running stack.** Run `scripts/gate.sh`.
  Then run this curl with a real JWT and expect a 201 whose `started_at`
  echoes the value sent:
  `curl -s -X POST localhost:8000/api/v1/pomodoro/sessions/ -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" -H "Idempotency-Key: $(uuidgen)" -d '{"session_type":"focus","duration_minutes":25,"started_at":"<an hour ago, ISO>"}'`

- [ ] **Step 8: Commit and PR.**
  - `test(#$SESSIONS): sessions keep the Mac's clock and their block` (the tests)
  - `feat(#$SESSIONS): …` (model, migration, serializer, service, view,
    fixture, CHANGELOG)

  Open a PR to `develop` with `Closes #$SESSIONS` and `Refs #129`.

---

### Task 2: Energy on the review (`$ENERGY`)

**Files:**
- Modify:
  - `backend/stats/models.py`
  - `backend/stats/serializers.py`
  - `backend/tools/tests/test_contract_fixtures.py`
  - `CHANGELOG.md`
- Create:
  - `backend/stats/migrations/000N_review_energy.py` (generated)
  - `backend/stats/tests/test_review_energy.py`

**Interfaces:**
- Produces: `DailyReview.energy: int | None` (1-3) in every review response,
  and the fixture `apps/apple/Fixtures/stats_review_list.json`.

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$ENERGY-review-energy develop`.

- [ ] **Step 2: Write the failing tests.**

```python
import pytest
from rest_framework import status

URL = "/api/v1/stats/reviews/"


@pytest.mark.django_db
class TestReviewEnergy:
    def test_energy_is_stored_and_returned(self, authenticated_client):
        resp = authenticated_client.post(URL, {"date": "2026-03-07", "energy": 2}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED, resp.data
        assert resp.data["energy"] == 2

    def test_energy_is_optional(self, authenticated_client):
        resp = authenticated_client.post(URL, {"date": "2026-03-07"}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["energy"] is None

    @pytest.mark.parametrize("energy", [0, 4])
    def test_energy_outside_one_to_three_is_a_400_naming_it(self, authenticated_client, energy):
        resp = authenticated_client.post(URL, {"date": "2026-03-07", "energy": energy}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert f"energy {energy}" in str(resp.data["energy"])
```

Add to `TestContractFixtures`:

```python
    def test_stats_review_list(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 7), productivity_rating=4, energy=2)
        resp = authenticated_client.get("/api/v1/stats/reviews/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("stats_review_list", _body(resp))
```

(Import `DailyReviewFactory`.)

- [ ] **Step 3: Run the tests.** They fail: `energy` is not a field.

- [ ] **Step 4: Implement.**

`backend/stats/models.py`: add the field after `win_of_the_day`, plus a
`constraints` entry in `Meta` beside `unique_together`.

```python
    # How the day felt, 1 (drained) to 3 (energised): the only source for
    # IDEA §13's energy mapping (#130).
    energy = models.PositiveSmallIntegerField(null=True, blank=True)
    ...
        constraints = [
            models.CheckConstraint(
                condition=models.Q(energy__isnull=True) | models.Q(energy__gte=1, energy__lte=3),
                name="dailyreview_energy_1_to_3",
            )
        ]
```

`backend/stats/serializers.py`: add `"energy"` to `fields` after
`"win_of_the_day"`, and add:

```python
    def validate_energy(self, value: int | None) -> int | None:
        # Invariant 3: a 400 here, before the check constraint can 500.
        if value is not None and not 1 <= value <= 3:
            raise serializers.ValidationError(f"energy {value} is not 1, 2 or 3")
        return value
```

Run `docker-compose exec backend python manage.py makemigrations stats -n review_energy`.

- [ ] **Step 5: Pass, regenerate the fixtures, and update the CHANGELOG.**
  `stats_review_list.json` appears. Under `### Added`, add:
  `- \`energy\` (1-3, optional) on the daily review (#$ENERGY, #130).`

- [ ] **Step 6: The gate and the running stack.**
  - Run `scripts/gate.sh`.
  - `curl` a POST to `stats/reviews/` with `"energy":2`: expect 201.
  - The same with `"energy":5`: expect a 400 naming it.

- [ ] **Step 7: Commit and PR.** Commits: `test(#$ENERGY): …`, then
  `feat(#$ENERGY): …`. The PR says `Closes #$ENERGY` and
  `Refs #130 (the review screen is M3.4)`.

---

### Task 3: The review is set by date (`$REVIEW`)

**Files:**
- Create:
  - `backend/stats/services.py`
  - `backend/stats/tests/test_review_by_date.py`
- Modify:
  - `backend/stats/views.py` (a `by_date` action on `DailyReviewViewSet`)
  - `backend/tools/tests/test_contract_fixtures.py`
  - `CHANGELOG.md`

**Interfaces:**
- Produces: `PUT stats/reviews/by-date/<YYYY-MM-DD>/` with a body of any of
  `productivity_rating`, `win_of_the_day`, `energy`, `is_shutdown`.
  - Returns 200 with the review; it was created if absent.
  - Returns 400 on a bad date.
- Produces the fixture `apps/apple/Fixtures/review_by_date.json`.
- Consumes: `energy` from Task 2. Stack this branch on
  `feat/$ENERGY-review-energy`, or start it after Task 2 merges.

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$REVIEW-review-by-date feat/$ENERGY-review-energy`.

- [ ] **Step 2: Write the failing tests.**

```python
import datetime

import pytest
from rest_framework import status

from conftest import DailyReviewFactory, UserFactory
from stats.models import DailyReview


def _url(day: str) -> str:
    return f"/api/v1/stats/reviews/by-date/{day}/"


@pytest.mark.django_db
class TestReviewByDate:
    def test_put_creates_the_days_review(self, authenticated_client, user):
        resp = authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 4}, format="json")
        assert resp.status_code == status.HTTP_200_OK, resp.data
        assert resp.data["date"] == "2026-03-07" and resp.data["productivity_rating"] == 4
        assert DailyReview.objects.filter(user=user).count() == 1

    def test_replaying_a_put_leaves_one_review_with_the_last_values(self, authenticated_client, user):
        authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 3}, format="json")
        authenticated_client.put(_url("2026-03-07"), {"productivity_rating": 5, "energy": 2}, format="json")
        review = DailyReview.objects.get(user=user)
        assert (review.productivity_rating, review.energy) == (5, 2)

    def test_a_put_leaves_fields_it_omits_alone(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 7), win_of_the_day="shipped")
        authenticated_client.put(_url("2026-03-07"), {"energy": 1}, format="json")
        assert DailyReview.objects.get(user=user).win_of_the_day == "shipped"

    def test_shutdown_is_stamped_by_the_server(self, authenticated_client):
        resp = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        assert resp.data["is_shutdown"] is True and resp.data["shutdown_at"] is not None

    def test_replayed_shutdown_keeps_the_first_stamp(self, authenticated_client, user):
        # Review Focus 5: the outbox may replay a write the server already applied.
        first = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        again = authenticated_client.put(_url("2026-03-07"), {"is_shutdown": True}, format="json")
        assert again.data["shutdown_at"] == first.data["shutdown_at"]

    def test_the_path_date_wins_over_a_body_date(self, authenticated_client, user):
        authenticated_client.put(_url("2026-03-07"), {"date": "2026-01-01", "energy": 2}, format="json")
        assert DailyReview.objects.get(user=user).date == datetime.date(2026, 3, 7)

    def test_a_bad_date_is_a_400_naming_it(self, authenticated_client):
        resp = authenticated_client.put(_url("07-03-2026"), {"energy": 2}, format="json")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert "07-03-2026" in str(resp.data)

    def test_another_users_review_is_untouched(self, authenticated_client, user):
        stranger = DailyReviewFactory(user=UserFactory(), date=datetime.date(2026, 3, 7), energy=3)
        authenticated_client.put(_url("2026-03-07"), {"energy": 1}, format="json")
        stranger.refresh_from_db()
        assert stranger.energy == 3
        assert DailyReview.objects.filter(user=user).count() == 1
```

Add to `TestContractFixtures`:

```python
    def test_review_by_date(self, authenticated_client):
        resp = authenticated_client.put(
            "/api/v1/stats/reviews/by-date/2026-03-07/",
            {"productivity_rating": 4, "win_of_the_day": "Shipped M3.1", "energy": 2},
            format="json",
        )
        assert resp.status_code == 200
        check_fixture("review_by_date", _body(resp))
```

- [ ] **Step 3: Run the tests.** They fail with 404, because the route
  doesn't exist yet.

- [ ] **Step 4: Implement.**

`backend/stats/services.py`:

```python
"""The daily review's writes that the views only parse and answer."""

import datetime

from django.utils import timezone

from .models import DailyReview

REVIEW_FIELDS = ("productivity_rating", "win_of_the_day", "energy", "is_shutdown")


def put_review(user, date: datetime.date, values: dict) -> DailyReview:
    """Create or update `user`'s one review for `date` with `values`.

    Idempotent by the natural key (user, date), so the Mac's outbox can replay
    it: a second shutdown keeps the first `shutdown_at`.

    >>> put_review(request.user, datetime.date(2026, 3, 7), {"energy": 2})
    """
    review, _ = DailyReview.objects.get_or_create(user=user, date=date)
    for field in REVIEW_FIELDS:
        if field in values:
            setattr(review, field, values[field])
    review.shutdown_at = _shutdown_stamp(review)
    review.save()
    return review


def _shutdown_stamp(review: DailyReview) -> datetime.datetime | None:
    if not review.is_shutdown:
        return None
    return review.shutdown_at or timezone.now()
```

`backend/stats/views.py`: add to `DailyReviewViewSet` (imports `action`,
`parse_client_date` and `put_review`).

```python
    @action(detail=False, methods=["put"], url_path=r"by-date/(?P<day>[^/]+)")
    def by_date(self, request, day=None):
        # The outbox's review write (M3.1 spec §1.3): the path's date is the
        # key, so a body `date` is ignored rather than trusted.
        target = parse_client_date(day)
        serializer = self.get_serializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        values = {k: v for k, v in serializer.validated_data.items() if k != "date"}
        return Response(self.get_serializer(put_review(request.user, target, values)).data)
```

The serializer's create-time check ("a review for this date already exists")
only runs when it validates a `date`. Because the view drops `date`, confirm
with the test that a replay isn't rejected. If it is, pass
`context={"request": request, "by_date": True}` and skip that branch when
`by_date` is set.

- [ ] **Step 5: Pass, regenerate the fixtures, and update the CHANGELOG.**
  Under `### Added`, add:
  `- \`PUT stats/reviews/by-date/<date>/\`: create or update the day's review, idempotent (#$REVIEW).`

- [ ] **Step 6: The gate and the running stack.**
  - Run `scripts/gate.sh`.
  - Run the same PUT twice with `curl`: both return 200, and a list call
    shows one review.
  - Send `is_shutdown` twice: `shutdown_at` is unchanged.

- [ ] **Step 7: Commit and PR.** Commits: `test(#$REVIEW): …`, then
  `feat(#$REVIEW): …`. This is a stacked PR; merge it after Task 2's.

---

### Task 4: Subtasks embedded in today and carried-over (`$SUBTASKS`)

**Files:**
- Modify:
  - `backend/tasks/serializers.py` (`TaskDayListSerializer`)
  - `backend/tasks/views.py` (`get_serializer_class`, and the prefetch for
    two actions)
  - `backend/tools/tests/test_contract_fixtures.py`
  - `CHANGELOG.md`
- Create: `backend/tasks/tests/test_day_subtasks.py`

**Interfaces:**
- Produces: tasks in `tasks/today/` and `tasks/carried-over/` gain
  `subtasks: [{id, title, is_completed, order, created_at}]`, ordered by
  `order` then `created_at`. This is the existing `SubtaskSerializer`, reused;
  its `created_at` is one field beyond the spec's list.
- The plain `tasks/` list is unchanged.
- Fixtures: `tasks_today.json` gains `subtasks`, and `tasks_carried_over.json`
  is new.

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$SUBTASKS-day-subtasks develop`.

- [ ] **Step 2: Write the failing tests.**

```python
import datetime

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from conftest import SubtaskFactory, TaskFactory

DAY = datetime.date(2026, 3, 7)


@pytest.mark.django_db
class TestDaySubtasks:
    def test_today_embeds_subtasks_in_order(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=DAY)
        SubtaskFactory(task=task, title="second", order=2)
        SubtaskFactory(task=task, title="first", order=1)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert [s["title"] for s in resp.data["results"][0]["subtasks"]] == ["first", "second"]

    def test_carried_over_embeds_subtasks(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=DAY - datetime.timedelta(days=1), is_completed=False)
        SubtaskFactory(task=task)
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-07")
        assert len(resp.data[0]["subtasks"]) == 1

    def test_the_plain_list_is_unchanged(self, authenticated_client, user):
        TaskFactory(user=user)
        resp = authenticated_client.get("/api/v1/tasks/")
        assert "subtasks" not in resp.data["results"][0]

    def test_embedding_adds_no_query_per_task(self, authenticated_client, user):
        def queries_for(count: int) -> int:
            for _ in range(count):
                SubtaskFactory(task=TaskFactory(user=user, scheduled_date=DAY))
            with CaptureQueriesContext(connection) as ctx:
                authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
            return len(ctx.captured_queries)

        assert queries_for(1) == queries_for(5)
```

Change `test_tasks_today` to also create a subtask
(`SubtaskFactory(task=task, title="Outline")`, importing it), so the
fixture's `subtasks` isn't an empty list. Then add:

```python
    def test_tasks_carried_over(self, authenticated_client, user):
        task = TaskFactory(
            user=user,
            scheduled_date=datetime.date(2026, 3, 6),
            is_completed=False,
            project=None,
            discipline=None,
        )
        SubtaskFactory(task=task, title="Outline")
        resp = authenticated_client.get("/api/v1/tasks/carried-over/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("tasks_carried_over", _body(resp))
```

- [ ] **Step 3: Run the tests.** Expect a `KeyError: 'subtasks'`. The
  `tasks_today` fixture check also fails, because its shape changed; that's
  the intended signal.

- [ ] **Step 4: Implement.**

`backend/tasks/serializers.py`: add after `TaskListSerializer`.

```python
class TaskDayListSerializer(TaskListSerializer):
    """A day's tasks with their subtasks, so Focus needs one request (M3.1 spec §1.4)."""

    subtasks = SubtaskSerializer(many=True, read_only=True)

    class Meta(TaskListSerializer.Meta):
        fields = TaskListSerializer.Meta.fields + ["subtasks"]
```

`backend/tasks/views.py`:

```python
    DAY_ACTIONS = ("today", "carried_over")

    def get_queryset(self):
        queryset = Task.objects.filter(user=self.request.user).prefetch_related("tags", "time_blocks")
        if self.action in self.DAY_ACTIONS:
            queryset = queryset.prefetch_related("subtasks")
        return queryset

    def get_serializer_class(self):
        if self.action in self.DAY_ACTIONS:
            return TaskDayListSerializer
        if self.action == "list":
            return TaskListSerializer
        return TaskSerializer
```

- [ ] **Step 5: Pass and regenerate the fixtures.** `tasks_today.json` gains
  `subtasks`, and `tasks_carried_over.json` is new. Under `### Changed`, add:
  `- \`tasks/today/\` and \`tasks/carried-over/\` embed each task's \`subtasks\` (#$SUBTASKS).`

- [ ] **Step 6: The gate, the running stack, commit and PR.** `curl`
  `tasks/today/?date=<today>` and check that `subtasks` is present. Commits
  are `test(#$SUBTASKS): …`, then `feat(#$SUBTASKS): …`.

---

### Task 5: The day's DTOs and API calls (`$DTOS`)

Start after Tasks 1-4 are merged, because their fixtures are this task's
input.

**Files:**
- Modify:
  - `backend/tools/tests/test_contract_fixtures.py` (fixtures for three
    unchanged endpoints)
  - `apps/apple/Packages/OmakaseAPI/Sources/OmakaseAPI/DTOs.swift`
    (`TaskDTO.subtasks`)
  - `apps/apple/Packages/OmakaseAPI/Sources/OmakaseAPI/APIClient.swift`
  - `apps/apple/Packages/OmakaseStore/Tests/OmakaseStoreTests/FakeAPIClient.swift`
- Create:
  - `apps/apple/Packages/OmakaseAPI/Sources/OmakaseAPI/DayDTOs.swift`
  - `apps/apple/Packages/OmakaseAPI/Tests/OmakaseAPITests/DayDTODecodingTests.swift`
  - `apps/apple/Packages/OmakaseAPI/Tests/OmakaseAPITests/DayAPIClientTests.swift`

**Interfaces:**
- Consumes: the fixtures `tasks_today`, `tasks_carried_over`,
  `pomodoro_session`, `stats_review_list`, `review_by_date`; and, new here,
  `timeblocks_day`, `studyblocks_day`, `profile`.
- Produces:

```swift
public struct SubtaskDTO: Sendable, Codable, Equatable, Identifiable { id: UUID; title: String; isCompleted: Bool; order: Int }
// TaskDTO gains: public let subtasks: [SubtaskDTO]?   // nil: this endpoint does not embed them
public struct TimeBlockDTO { id: UUID; task: UUID?; studyBlock: UUID?; date: APIDay; startTime: String; endTime: String; notes: String; sessionRating: Int? }
public struct StudyBlockDTO { id: UUID; discipline: UUID; title: String; priority: String; status: String; estimatedMinutes: Int?; scheduledDate: APIDay?; isCompleted: Bool }
public struct PomodoroSessionDTO { id: UUID; task: UUID?; timeBlock: UUID?; sessionType: String; durationMinutes: Int; startedAt: Date; endedAt: Date?; completed: Bool }
public struct DailyReviewDTO { id: UUID; date: APIDay; productivityRating: Int?; winOfTheDay: String; energy: Int?; isShutdown: Bool; shutdownAt: Date? }
public struct ProfileDTO { pomodoroWorkMinutes, pomodoroShortBreakMinutes, pomodoroLongBreakMinutes, pomodorosBeforeLongBreak: Int; dailyWorkGoalHours, dailyStudyGoalHours: String; var workGoalHours: Double; var studyGoalHours: Double }
// APIClient gains:
func carriedOver(on day: APIDay) async throws -> [TaskDTO]
func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO]
func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO]
func review(on day: APIDay) async throws -> DailyReviewDTO?
func profile() async throws -> ProfileDTO
```

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$DTOS-day-dtos develop`.

- [ ] **Step 2: Add the three missing fixtures.** Add to `TestContractFixtures`
  (importing `StudyBlockFactory, DisciplineFactory, SemesterFactory,
  TimeBlockFactory`):

```python
    def test_timeblocks_day(self, authenticated_client, user):
        TimeBlockFactory(
            task=TaskFactory(user=user, project=None, discipline=None),
            date=datetime.date(2026, 3, 7),
            notes="Draft",
            session_rating=4,
        )
        resp = authenticated_client.get("/api/v1/timeblocks/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("timeblocks_day", _body(resp))

    def test_studyblocks_day(self, authenticated_client, user):
        discipline = DisciplineFactory(semester=SemesterFactory(user=user))
        StudyBlockFactory(discipline=discipline, scheduled_date=datetime.date(2026, 3, 7), estimated_minutes=45)
        resp = authenticated_client.get("/api/v1/study/studyblocks/?scheduled_date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("studyblocks_day", _body(resp))

    def test_profile(self, authenticated_client):
        resp = authenticated_client.get("/api/v1/auth/profile/")
        assert resp.status_code == 200
        check_fixture("profile", _body(resp))
```

Run them with `WRITE_CONTRACT_FIXTURES=1`, then without, and check that
`profile.json` holds `"daily_work_goal_hours": "…"` as a **string** (Review
Focus 1). Commit:
`test(#$DTOS): contract fixtures for the day's reads`.

- [ ] **Step 3: Write the failing DTO tests** in
  `DayDTODecodingTests.swift`.

```swift
import Foundation
import Testing

@testable import OmakaseAPI

struct DayDTODecodingTests {
    @Test func todaysTasksCarryTheirSubtasks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TaskDTO>.self, from: Fixture.data("tasks_today"))
        let subtask = try #require(page.results.first?.subtasks?.first)
        #expect(subtask.title == "Outline" && !subtask.isCompleted)
    }

    @Test func aTaskWithoutEmbeddedSubtasksDecodesAsNil() throws {
        // The plain tasks/ list sends no `subtasks`: nil, so sync leaves local subtasks alone.
        let page = try JSONSerialization.jsonObject(with: Fixture.data("tasks_today")) as? [String: Any]
        var task = try #require((page?["results"] as? [[String: Any]])?.first)
        task["subtasks"] = nil
        let data = try JSONSerialization.data(withJSONObject: task)
        #expect(try OmakaseJSON.decoder.decode(TaskDTO.self, from: data).subtasks == nil)
    }

    @Test func decodesCarriedOverAsAPlainList() throws {
        let tasks = try OmakaseJSON.decoder.decode([TaskDTO].self, from: Fixture.data("tasks_carried_over"))
        #expect(tasks.first?.scheduledDate?.string == "2026-03-06")
    }

    @Test func decodesTheDaysTimeBlocks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TimeBlockDTO>.self, from: Fixture.data("timeblocks_day"))
        let block = try #require(page.results.first)
        #expect(block.date.string == "2026-03-07" && block.notes == "Draft" && block.sessionRating == 4)
        #expect(block.task != nil && block.studyBlock == nil)
    }

    @Test func decodesTheDaysStudyBlocks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<StudyBlockDTO>.self, from: Fixture.data("studyblocks_day"))
        #expect(page.results.first?.estimatedMinutes == 45)
    }

    @Test func decodesASession() throws {
        let session = try OmakaseJSON.decoder.decode(PomodoroSessionDTO.self, from: Fixture.data("pomodoro_session"))
        #expect(session.timeBlock != nil && session.completed && session.durationMinutes == 25)
    }

    @Test func decodesAReviewWithEnergy() throws {
        let review = try OmakaseJSON.decoder.decode(DailyReviewDTO.self, from: Fixture.data("review_by_date"))
        #expect(review.energy == 2 && review.productivityRating == 4 && !review.isShutdown)
    }

    @Test func decodesDecimalGoalHoursAsStrings() throws {
        // Review Focus 1: DRF sends DecimalField as "4.0", not 4.0.
        let profile = try OmakaseJSON.decoder.decode(ProfileDTO.self, from: Fixture.data("profile"))
        #expect(profile.pomodoroWorkMinutes == 25 && profile.pomodorosBeforeLongBreak == 4)
        #expect(profile.workGoalHours > 0)
    }
}
```

Run `swift test --package-path apps/apple/Packages/OmakaseAPI`. Expected: it
fails to compile, because the DTOs don't exist.

- [ ] **Step 4: Implement the DTOs.** Add
  `public let subtasks: [SubtaskDTO]?` to `TaskDTO` in `DTOs.swift`, after
  `updatedAt`, with the doc comment
  `/// Embedded by today and carried-over only; nil elsewhere, and then sync leaves local subtasks alone.`

`DayDTOs.swift`:

```swift
import Foundation

/// A subtask as `tasks/today/` embeds it (`SubtaskSerializer`).
public struct SubtaskDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let isCompleted: Bool
    public let order: Int
}

/// `TimeBlockSerializer`: exactly one of `task` and `studyBlock` is set.
/// Times are the server's `HH:MM:SS` wall-clock strings for `date`.
public struct TimeBlockDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let task: UUID?
    public let studyBlock: UUID?
    public let date: APIDay
    public let startTime: String
    public let endTime: String
    public let notes: String
    public let sessionRating: Int?
}

/// `StudyBlockSerializer`, the fields the day uses.
public struct StudyBlockDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let discipline: UUID
    public let title: String
    public let priority: String
    public let status: String
    public let estimatedMinutes: Int?
    public let scheduledDate: APIDay?
    public let isCompleted: Bool
}

/// `PomodoroSessionSerializer`: `startedAt` is the Mac's clock (M3.1 spec §1.1).
public struct PomodoroSessionDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let task: UUID?
    public let timeBlock: UUID?
    public let sessionType: String
    public let durationMinutes: Int
    public let startedAt: Date
    public let endedAt: Date?
    public let completed: Bool
}

/// `DailyReviewSerializer`: one per user and day.
public struct DailyReviewDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: APIDay
    public let productivityRating: Int?
    public let winOfTheDay: String
    public let energy: Int?
    public let isShutdown: Bool
    public let shutdownAt: Date?
}

/// `UserProfileSerializer`. The goal hours are `DecimalField`s, which DRF
/// sends as strings ("4.0"); the doubles are read from them (Review Focus 1).
public struct ProfileDTO: Sendable, Codable, Equatable {
    public let pomodoroWorkMinutes: Int
    public let pomodoroShortBreakMinutes: Int
    public let pomodoroLongBreakMinutes: Int
    public let pomodorosBeforeLongBreak: Int
    public let dailyWorkGoalHours: String
    public let dailyStudyGoalHours: String

    public var workGoalHours: Double { Double(dailyWorkGoalHours) ?? 0 }
    public var studyGoalHours: Double { Double(dailyStudyGoalHours) ?? 0 }
}
```

Run the tests again. Expected: all pass.

- [ ] **Step 5: Write the failing client tests** in
  `DayAPIClientTests.swift`.

```swift
import Foundation
import Testing

@testable import OmakaseAPI

struct DayAPIClientTests {
    private let base = URL(string: "http://localhost:8000")!
    private let day = APIDay(string: "2026-03-07")!

    private func client(_ replies: [Result<FakeHTTPTransport.Reply, URLError>]) -> (OmakaseAPIClient, FakeHTTPTransport) {
        let transport = FakeHTTPTransport(replies)
        let tokens = InMemoryTokenStore(.init(access: "a1", refresh: "r1"))
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: tokens), transport)
    }

    private func sentURL(_ transport: FakeHTTPTransport) async -> String? {
        let request = await transport.sent.first
        return request?.url.map { $0.path() + "?" + ($0.query() ?? "") }
    }

    @Test func carriedOverSendsTheDay() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("tasks_carried_over")))])
        #expect(try await api.carriedOver(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/tasks/carried-over/?date=2026-03-07")
    }

    @Test func timeBlocksSendTheDay() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("timeblocks_day")))])
        #expect(try await api.timeBlocks(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/timeblocks/?date=2026-03-07")
    }

    @Test func studyBlocksFilterByScheduledDate() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("studyblocks_day")))])
        #expect(try await api.studyBlocks(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/study/studyblocks/?scheduled_date=2026-03-07")
    }

    @Test func reviewIsTheDaysOnlyReview() async throws {
        let (api, _) = client([.success(.init(status: 200, body: try Fixture.data("stats_review_list")))])
        #expect(try await api.review(on: day)?.energy == 2)
    }

    @Test func noReviewYetIsNil() async throws {
        let (api, _) = client([FakeHTTPTransport.json(200, #"{"count":0,"next":null,"previous":null,"results":[]}"#)])
        #expect(try await api.review(on: day) == nil)
    }

    @Test func profileIsFetched() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("profile")))])
        #expect(try await api.profile().pomodoroWorkMinutes == 25)
        #expect(await transport.sent.first?.url?.path() == "/api/v1/auth/profile/")
    }
}
```

- [ ] **Step 6: Implement the calls.** In `APIClient.swift`:
  - add the five requirements to the `APIClient` protocol
  - extract the paging loop from `tasks(on:)` into
    `private func allPages<Item: Decodable & Sendable & Equatable & Codable>(_ path: String) async throws -> [Item]`
  - make `tasks(on:)` return
    `try await allPages("/api/v1/tasks/today/?date=\(day.string)")`
  - add:

```swift
    public func carriedOver(on day: APIDay) async throws -> [TaskDTO] {
        // Not paginated: the action returns a plain list (backend/tasks/views.py).
        try decode(try await authorized("GET", "/api/v1/tasks/carried-over/?date=\(day.string)"))
    }

    public func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO] {
        try await allPages("/api/v1/timeblocks/?date=\(day.string)")
    }

    public func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO] {
        try await allPages("/api/v1/study/studyblocks/?scheduled_date=\(day.string)")
    }

    public func review(on day: APIDay) async throws -> DailyReviewDTO? {
        let reviews: [DailyReviewDTO] = try await allPages("/api/v1/stats/reviews/?date=\(day.string)")
        return reviews.first
    }

    public func profile() async throws -> ProfileDTO {
        try decode(try await authorized("GET", "/api/v1/auth/profile/"))
    }
```

In `FakeAPIClient.swift` (Store tests), add settable storage and the five
methods, so the Store package compiles:

```swift
    private var carriedByDay: [String: [TaskDTO]] = [:]
    private var blocksByDay: [String: [TimeBlockDTO]] = [:]
    private var studiesByDay: [String: [StudyBlockDTO]] = [:]
    private var reviewsByDay: [String: DailyReviewDTO] = [:]
    private var storedProfile: ProfileDTO?
    private(set) var requestedDays: [String] = []

    func setCarriedOver(_ tasks: [TaskDTO], on day: String) { carriedByDay[day] = tasks }
    func setBlocks(_ blocks: [TimeBlockDTO], on day: String) { blocksByDay[day] = blocks }
    func setStudies(_ studies: [StudyBlockDTO], on day: String) { studiesByDay[day] = studies }
    func setReview(_ review: DailyReviewDTO?, on day: String) { reviewsByDay[day] = review }
    func setProfile(_ profile: ProfileDTO) { storedProfile = profile }

    func carriedOver(on day: APIDay) async throws -> [TaskDTO] { note(day); return carriedByDay[day.string] ?? [] }
    func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO] { note(day); return blocksByDay[day.string] ?? [] }
    func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO] { note(day); return studiesByDay[day.string] ?? [] }
    func review(on day: APIDay) async throws -> DailyReviewDTO? { note(day); return reviewsByDay[day.string] }
    func profile() async throws -> ProfileDTO {
        guard let storedProfile else { throw APIError.transport("no profile scripted") }
        return storedProfile
    }

    private func note(_ day: APIDay) { requestedDays.append(day.string) }
```

In the same file, make `tasks(on:)` call `note(day)` as well.
`requestedDays` is how Task 6 pins Review Focus 4.

- [ ] **Step 7: Pass and run the gate.**
  - `swift test` passes for OmakaseAPI and OmakaseStore.
  - `apps/apple/gate.sh` exits 0.

- [ ] **Step 8: Commit and PR.** Commits:
  - `test(#$DTOS): the day's DTOs decode their fixtures`
  - `feat(#$DTOS): DTOs for the day`
  - `test(#$DTOS): the day's API calls`
  - `feat(#$DTOS): APIClient reads the whole day`

  Open a PR to `develop`.

---

### Task 6: Day records and `DaySync` (`$SYNC`)

**Files:**
- Modify:
  - `apps/apple/Packages/OmakaseStore/Sources/OmakaseStore/Records.swift`
    (`TaskRecord` fields)
  - `apps/apple/Packages/OmakaseStore/Sources/OmakaseStore/StoreSchema.swift`
    (models)
  - `apps/apple/OmakaseMac/AppServices.swift` (`TodaySync` becomes `DaySync`)
- Create:
  - `.../OmakaseStore/DayRecords.swift`
  - `.../OmakaseStore/DayApply.swift`
- Rename:
  - `TodaySync.swift` becomes `DaySync.swift`
  - `TodaySyncTests.swift` becomes `DaySyncTests.swift`

  Keep every existing test's assertions, and change only the type name.

**Interfaces:**
- Consumes: Task 5's DTOs and `APIClient` calls, and `FakeAPIClient.requestedDays`.
- Produces:

```swift
// TaskRecord gains (defaults so SwiftData migrates M1/M2 stores): kanbanStatus: String = "todo",
//   dueDay: String? = nil, estimatedMinutes: Int? = nil, isCarriedOver: Bool = false
@Model SubtaskRecord { id, taskID, title, isCompleted, order }            // init(dto:taskID:), apply(_:)
@Model TimeBlockRecord { id, day, startTime, endTime, taskID?, studyBlockID?, notes, sessionRating? }
@Model StudyBlockRecord { id, title, disciplineID, scheduledDay?, isCompleted, estimatedMinutes?, priority, status }
@Model DailyReviewRecord { day (unique), rating?, win, energy?, isShutdown, shutdownAt? }
@Model ProfileRecord { key = "me" (unique), workMinutes, shortBreakMinutes, longBreakMinutes, beforeLongBreak, workGoalHours, studyGoalHours }
DailyReviewRecord.subjectID(for day: String) -> String   // "review-<day>", the outbox subject for a review
@MainActor public final class DaySync { init(context:api:clock:calendar:); func refresh() async throws }
```

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$SYNC-day-sync feat/$DTOS-day-dtos`.
  Rename the two files with `git mv`, and rename the type and its test
  helper. The existing tests must pass unchanged before anything new is
  added.

- [ ] **Step 2: Write the failing tests** in `DaySyncTests.swift`, next to
  the kept ones. Add two helpers to `FakeAPIClient.swift`'s DTO extensions:
  `TimeBlockDTO.make(id:day:task:)` and `DailyReviewDTO.make(day:energy:)`.
  Both decode a JSON literal, like `TaskDTO.make`. Also add
  `ProfileDTO.make()`, which decodes the `profile` fixture's values inline.

```swift
    @Test func oneRefreshAsksForOneDay() async throws {
        // Review Focus 4: every request of one refresh names the same day.
        await api.setProfile(try .make())
        try await sync().refresh()
        #expect(Set(await api.requestedDays) == ["2026-03-07"])
    }

    @Test func carriedOverTasksAreMarked() async throws {
        await api.setProfile(try .make())
        await api.setCarriedOver([try .make(title: "Yesterday's", day: "2026-03-06")], on: "2026-03-07")
        try await sync().refresh()
        #expect(try records().first?.isCarriedOver == true)
    }

    @Test func embeddedSubtasksAreStoredAndDroppedOnesRemoved() async throws {
        await api.setProfile(try .make())
        let task = try TaskDTO.make(title: "Parent", subtasks: [("a", false), ("b", true)])
        await api.setTasks([task], on: "2026-03-07")
        try await sync().refresh()
        #expect(try subtasks().map(\.title) == ["a", "b"])
        await api.setTasks([try TaskDTO.make(id: task.id, title: "Parent", subtasks: [("a", false)])], on: "2026-03-07")
        try await sync().refresh()
        #expect(try subtasks().map(\.title) == ["a"])
    }

    @Test func blocksReviewAndProfileAreCached() async throws {
        await api.setProfile(try .make())
        await api.setBlocks([try .make(day: "2026-03-07")], on: "2026-03-07")
        await api.setReview(try .make(day: "2026-03-07", energy: 2), on: "2026-03-07")
        try await sync().refresh()
        let context = container.mainContext
        #expect(try context.fetch(FetchDescriptor<TimeBlockRecord>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DailyReviewRecord>()).first?.energy == 2)
        #expect(try context.fetch(FetchDescriptor<ProfileRecord>()).first?.workMinutes == 25)
    }

    @Test func aBlockGoneFromTheServerIsRemovedUnlessQueued() async throws {
        await api.setProfile(try .make())
        let kept = try TimeBlockDTO.make(day: "2026-03-07")
        await api.setBlocks([try .make(day: "2026-03-07"), kept], on: "2026-03-07")
        try await sync().refresh()
        container.mainContext.insert(
            OutboxEntry(sequence: 1, method: "PATCH", path: "/x", body: nil, subjectID: kept.id.uuidString))
        await api.setBlocks([], on: "2026-03-07")
        try await sync().refresh()
        #expect(try container.mainContext.fetch(FetchDescriptor<TimeBlockRecord>()).map(\.id) == [kept.id.uuidString])
    }

    @Test func aQueuedReviewKeepsItsLocalValues() async throws {
        await api.setProfile(try .make())
        container.mainContext.insert(DailyReviewRecord(day: "2026-03-07", energy: 3))
        container.mainContext.insert(
            OutboxEntry(sequence: 1, method: "PUT", path: "/r", body: nil,
                        subjectID: DailyReviewRecord.subjectID(for: "2026-03-07")))
        await api.setReview(try .make(day: "2026-03-07", energy: 1), on: "2026-03-07")
        try await sync().refresh()
        #expect(try container.mainContext.fetch(FetchDescriptor<DailyReviewRecord>()).first?.energy == 3)
    }

    @Test func theDayIsRecomputedAfterMidnight() async throws {
        await api.setProfile(try .make())
        let daySync = sync()
        try await daySync.refresh()
        clock.now = clock.now.addingTimeInterval(13 * 3600)  // 2026-03-08 01:00 UTC
        try await daySync.refresh()
        #expect(await api.requestedDays.last == "2026-03-08")
    }
```

`TaskDTO.make` gains a `subtasks: [(String, Bool)]? = nil` parameter, which
emits `"subtasks":[{"id":…,"title":…,"is_completed":…,"order":i}]` when set.
`subtasks()` is a `FetchDescriptor<SubtaskRecord>` sorted by `order`.

Because `profile()` now throws when unscripted, the kept tests each gain
`await api.setProfile(try .make())` as their first line. That's a
precondition, not a change to what they assert.

Run `swift test --package-path apps/apple/Packages/OmakaseStore`. Expected: it
fails to compile, because the records and `DaySync` don't exist yet.

- [ ] **Step 3: Implement the records.** In `Records.swift`, `TaskRecord`
  gains:

```swift
    public var kanbanStatus: String = "todo"
    public var dueDay: String? = nil
    public var estimatedMinutes: Int? = nil
    /// Scheduled before today and not done: shown apart in Focus (#129).
    public var isCarriedOver: Bool = false
```

`apply(_:)` also sets `kanbanStatus`, `dueDay` (`dto.dueDate?.string`) and
`estimatedMinutes`. `init(dto:)` sets them the same way.

`DayRecords.swift`:

```swift
import Foundation
import OmakaseAPI
import SwiftData

/// A task's subtask; deleted with its task by DaySync (no SwiftData relationship,
/// so a subtask can arrive before its task's record exists).
@Model
public final class SubtaskRecord {
    @Attribute(.unique) public var id: String
    public var taskID: String
    public var title: String
    public var isCompleted: Bool
    public var order: Int

    public init(dto: SubtaskDTO, taskID: String) {
        (id, self.taskID) = (dto.id.uuidString, taskID)
        (title, isCompleted, order) = (dto.title, dto.isCompleted, dto.order)
    }

    public func apply(_ dto: SubtaskDTO) { (title, isCompleted, order) = (dto.title, dto.isCompleted, dto.order) }
}

/// A block on the day: session notes and rating are written here (M3.3).
@Model
public final class TimeBlockRecord {
    @Attribute(.unique) public var id: String
    public var day: String
    public var startTime: String
    public var endTime: String
    public var taskID: String?
    public var studyBlockID: String?
    public var notes: String
    public var sessionRating: Int?

    public init(dto: TimeBlockDTO) {
        id = dto.id.uuidString
        (day, startTime, endTime, notes, sessionRating) = ("", "", "", "", nil)
        apply(dto)
    }

    public func apply(_ dto: TimeBlockDTO) {
        (day, startTime, endTime) = (dto.date.string, dto.startTime, dto.endTime)
        (taskID, studyBlockID) = (dto.task?.uuidString, dto.studyBlock?.uuidString)
        (notes, sessionRating) = (dto.notes, dto.sessionRating)
    }
}

/// A study block scheduled for the day.
@Model
public final class StudyBlockRecord {
    @Attribute(.unique) public var id: String
    public var title: String
    public var disciplineID: String
    public var scheduledDay: String?
    public var isCompleted: Bool
    public var estimatedMinutes: Int?
    public var priority: String
    public var status: String

    public init(dto: StudyBlockDTO) {
        (id, title, disciplineID, priority, status) = (dto.id.uuidString, "", "", "", "")
        (isCompleted, scheduledDay, estimatedMinutes) = (false, nil, nil)
        apply(dto)
    }

    public func apply(_ dto: StudyBlockDTO) {
        (title, disciplineID, scheduledDay) = (dto.title, dto.discipline.uuidString, dto.scheduledDate?.string)
        (isCompleted, estimatedMinutes) = (dto.isCompleted, dto.estimatedMinutes)
        (priority, status) = (dto.priority, dto.status)
    }
}

/// The day's one review.
@Model
public final class DailyReviewRecord {
    @Attribute(.unique) public var day: String
    public var rating: Int?
    public var win: String
    public var energy: Int?
    public var isShutdown: Bool
    public var shutdownAt: Date?

    public init(day: String, rating: Int? = nil, win: String = "", energy: Int? = nil) {
        (self.day, self.rating, self.win, self.energy) = (day, rating, win, energy)
        (isShutdown, shutdownAt) = (false, nil)
    }

    public func apply(_ dto: DailyReviewDTO) {
        (rating, win, energy) = (dto.productivityRating, dto.winOfTheDay, dto.energy)
        (isShutdown, shutdownAt) = (dto.isShutdown, dto.shutdownAt)
    }

    /// The outbox subject for a day's review, which has no server id until it exists.
    public static func subjectID(for day: String) -> String { "review-\(day)" }
}

/// The user's pomodoro and goal settings: one row.
@Model
public final class ProfileRecord {
    @Attribute(.unique) public var key: String = "me"
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var beforeLongBreak: Int
    public var workGoalHours: Double
    public var studyGoalHours: Double

    public init(dto: ProfileDTO) {
        (workMinutes, shortBreakMinutes, longBreakMinutes, beforeLongBreak) = (0, 0, 0, 0)
        (workGoalHours, studyGoalHours) = (0, 0)
        apply(dto)
    }

    public func apply(_ dto: ProfileDTO) {
        (workMinutes, shortBreakMinutes) = (dto.pomodoroWorkMinutes, dto.pomodoroShortBreakMinutes)
        (longBreakMinutes, beforeLongBreak) = (dto.pomodoroLongBreakMinutes, dto.pomodorosBeforeLongBreak)
        (workGoalHours, studyGoalHours) = (dto.workGoalHours, dto.studyGoalHours)
    }
}
```

In `StoreSchema.models`, append `SubtaskRecord.self`,
`TimeBlockRecord.self`, `StudyBlockRecord.self`, `DailyReviewRecord.self`
and `ProfileRecord.self`.

- [ ] **Step 4: Implement `DaySync` and `DayApply`.** `DaySync.swift`
  keeps `TodaySync`'s init and doc comment, with the type renamed.

```swift
    /// "Today" is computed once per refresh, from the clock, so all six
    /// requests name the same day even across midnight (Review Focus 4).
    public func refresh() async throws {
        let day = APIDay.today(calendar: calendar, now: clock())
        async let today = api.tasks(on: day)
        async let carried = api.carriedOver(on: day)
        async let blocks = api.timeBlocks(on: day)
        async let studies = api.studyBlocks(on: day)
        async let review = api.review(on: day)
        async let profile = api.profile()
        let apply = DayApply(context: context, pending: try pendingSubjects())
        try apply.tasks(try await today, carried: try await carried, on: day.string)
        try apply.blocks(try await blocks, on: day.string)
        try apply.studies(try await studies, on: day.string)
        try apply.review(try await review, on: day.string)
        try apply.profile(try await profile)
        try context.save()
    }
```

`DayApply.swift`: one `@MainActor struct DayApply`, which holds
`context: ModelContext` and `pending: Set<String>`. Each function stays
≤ 20 lines:

```swift
@MainActor
struct DayApply {
    let context: ModelContext
    let pending: Set<String>

    func tasks(_ today: [TaskDTO], carried: [TaskDTO], on day: String) throws {
        for dto in today { try upsertTask(dto, carried: false) }
        for dto in carried { try upsertTask(dto, carried: true) }
        let keep = Set((today + carried).map(\.id.uuidString)).union(pending)
        let onDay: String? = day
        let stale = try context.fetch(
            FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.scheduledDay == onDay || $0.isCarriedOver }))
        for record in stale where !keep.contains(record.id) && !record.id.hasPrefix("local-") {
            try deleteSubtasks(of: record.id)
            context.delete(record)
        }
    }

    private func upsertTask(_ dto: TaskDTO, carried: Bool) throws {
        let id = dto.id.uuidString
        guard !pending.contains(id) else { return }
        let record = try fetchTask(id) ?? { let made = TaskRecord(dto: dto); context.insert(made); return made }()
        record.apply(dto)
        record.isCarriedOver = carried
        if let subtasks = dto.subtasks { try replaceSubtasks(of: id, with: subtasks) }
    }

    private func replaceSubtasks(of taskID: String, with dtos: [SubtaskDTO]) throws {
        let fresh = Dictionary(uniqueKeysWithValues: dtos.map { ($0.id.uuidString, $0) })
        for record in try subtasks(of: taskID) where fresh[record.id] == nil && !pending.contains(record.id) {
            context.delete(record)
        }
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let existing = try context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.id == id })).first
            if let existing { existing.apply(dto) } else { context.insert(SubtaskRecord(dto: dto, taskID: taskID)) }
        }
    }

    func blocks(_ dtos: [TimeBlockDTO], on day: String) throws {
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let existing = try context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id })).first
            if let existing { existing.apply(dto) } else { context.insert(TimeBlockRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString)).union(pending)
        for record in try context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.day == day }))
        where !keep.contains(record.id) { context.delete(record) }
    }

    func studies(_ dtos: [StudyBlockDTO], on day: String) throws {
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let existing = try context.fetch(FetchDescriptor<StudyBlockRecord>(predicate: #Predicate { $0.id == id })).first
            if let existing { existing.apply(dto) } else { context.insert(StudyBlockRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString)).union(pending)
        let onDay: String? = day
        for record in try context.fetch(FetchDescriptor<StudyBlockRecord>(predicate: #Predicate { $0.scheduledDay == onDay }))
        where !keep.contains(record.id) { context.delete(record) }
    }

    func review(_ dto: DailyReviewDTO?, on day: String) throws {
        guard !pending.contains(DailyReviewRecord.subjectID(for: day)) else { return }
        let existing = try context.fetch(FetchDescriptor<DailyReviewRecord>(predicate: #Predicate { $0.day == day })).first
        switch (dto, existing) {
        case (let dto?, let record?): record.apply(dto)
        case (let dto?, nil):
            let record = DailyReviewRecord(day: day)
            record.apply(dto)
            context.insert(record)
        case (nil, let record?): context.delete(record)
        case (nil, nil): break
        }
    }

    func profile(_ dto: ProfileDTO) throws {
        if let record = try context.fetch(FetchDescriptor<ProfileRecord>()).first { record.apply(dto) }
        else { context.insert(ProfileRecord(dto: dto)) }
    }

    private func fetchTask(_ id: String) throws -> TaskRecord? {
        try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func subtasks(of taskID: String) throws -> [SubtaskRecord] {
        try context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.taskID == taskID }))
    }

    private func deleteSubtasks(of taskID: String) throws {
        for record in try subtasks(of: taskID) { context.delete(record) }
    }
}
```

If SwiftLint flags any function above 20 lines or CC 10 after formatting,
split it. `blocks` and `studies` share a shape, but their records are
different `@Model` types, and a `#Predicate` doesn't work through a
protocol; keep them parallel and small, and don't write a generic that the
macro can't expand.

In `AppServices.swift`, replace `TodaySync(` with `DaySync(`.

- [ ] **Step 5: Pass and run the gate.** `swift test` passes for
  OmakaseStore, and `apps/apple/gate.sh` exits 0.

- [ ] **Step 6: Check the real app.**
  - Launch the built app against `docker-compose up` with an existing M2
    store. SwiftData must migrate it, with the tasks still shown.
  - Run M1's `SMOKE.md` steps 1-3.
  - Record both results in the PR.

- [ ] **Step 7: Commit and PR.** Commits:
  - `refactor(#$SYNC): TodaySync becomes DaySync` (the rename alone, with the
    tests unchanged)
  - `test(#$SYNC): …`
  - `feat(#$SYNC): day records`
  - `feat(#$SYNC): DaySync fetches and applies the whole day`

  Stack the PR on Task 5's.

---

### Task 7: Outbox kinds, handlers, and the task writes (`$KINDS`)

**Files:**
- Modify:
  - `.../OmakaseStore/Records.swift` (`OutboxEntry.kind`)
  - `.../OmakaseStore/OutboxWorker.swift` (handlers instead of `onAccepted`)
  - `.../OmakaseStore/TaskWrites.swift`
  - `.../OmakaseStore/Tests/OmakaseStoreTests/OutboxWorkerTests.swift` and
    `TaskWritesTests.swift` (constructor change only)
  - `apps/apple/OmakaseMac/AppServices.swift`
  - `docs/superpowers/specs/2026-09-25-macos-client-design.md` (the
    `inFlight` note)
- Create:
  - `.../OmakaseStore/OutboxHandlers.swift`
  - `.../OmakaseStore/OutboxQueue.swift`
  - `.../OmakaseStore/TaskHandler.swift`
  - `.../OmakaseStore/Tests/OmakaseStoreTests/OutboxKindTests.swift`

**Interfaces:**
- Consumes: Task 6's `TaskRecord` fields.
- Produces:

```swift
// OutboxEntry: public var kind: String = "task.patch";  init(..., kind: String = "task.patch")
@MainActor public protocol OutboxHandler { var kinds: [String] { get }; func apply(_ entry: OutboxEntry, body: Data) }
@MainActor public struct OutboxHandlers { init(_ handlers: [any OutboxHandler]); func handles(_ kind: String) -> Bool; func apply(_ entry: OutboxEntry, body: Data) }
// OutboxWorker.init(context:api:clock:handlers: OutboxHandlers)   — replaces onAccepted
@MainActor public struct OutboxQueue {
    init(context: ModelContext)
    func enqueue(kind: String, method: String, path: String, body: Data?, subjectID: String?, createsLocalID: String? = nil) throws
    func hasLaterPendingWrite(than entry: OutboxEntry, for ids: [String]) -> Bool
}
public final class TaskHandler: OutboxHandler   // kinds ["task.patch", "task.create"]; init(context:)
// TaskWrites: toggleCompletion(_:), setKanbanStatus(_:to:), reschedule(_:to day: String?), capture(title:day:) -> TaskRecord
```

- [ ] **Step 1: Branch.** Run `git checkout -b feat/$KINDS-outbox-kinds feat/$SYNC-day-sync`.

- [ ] **Step 2: Write the failing tests** in `OutboxKindTests.swift`.
  Reuse `OutboxWorkerTests`' container and `FakeAPIClient` setup.

```swift
    @Test func anM1EntryWithNoKindReplaysAsATaskPatch() {
        let entry = OutboxEntry(sequence: 1, method: "PATCH", path: "/api/v1/tasks/x/", body: nil, subjectID: "x")
        #expect(entry.kind == "task.patch")
    }

    @Test func anUnknownKindParksWithoutBeingSent() async throws {
        let context = container.mainContext
        context.insert(OutboxEntry(sequence: 1, method: "POST", path: "/x", body: nil, subjectID: nil, kind: "mystery"))
        let worker = OutboxWorker(context: context, api: api, handlers: OutboxHandlers([TaskHandler(context: context)]))
        #expect(await worker.drain() == .empty)
        let parked = try #require(try context.fetch(FetchDescriptor<OutboxEntry>()).first)
        #expect(parked.state == .parked && parked.lastError?.contains("mystery") == true)
        #expect(await api.sentRequests.isEmpty)
    }

    @Test func completingMovesTheTaskToDoneAndBack() throws {
        let record = TaskRecord(id: "t1", title: "T")
        container.mainContext.insert(record)
        let writes = TaskWrites(context: container.mainContext)
        try writes.toggleCompletion(record)
        #expect(record.isCompleted && record.kanbanStatus == "done")
        try writes.toggleCompletion(record)
        #expect(!record.isCompleted && record.kanbanStatus == "todo")
    }

    @Test func movingToDoneCompletesTheTask() throws {
        let record = TaskRecord(id: "t1", title: "T")
        container.mainContext.insert(record)
        try TaskWrites(context: container.mainContext).setKanbanStatus(record, to: "done")
        #expect(record.isCompleted && record.completedAt != nil)
        let entry = try #require(try container.mainContext.fetch(FetchDescriptor<OutboxEntry>()).first)
        #expect(entry.kind == "task.patch" && String(bytes: entry.body!, encoding: .utf8) == #"{"kanban_status":"done"}"#)
    }

    @Test func reschedulingToBacklogSendsAnExplicitNull() throws {
        // Review Focus 2: a synthesized Encodable would omit nil and change nothing.
        let record = TaskRecord(id: "t1", title: "T", scheduledDay: "2026-03-07")
        container.mainContext.insert(record)
        try TaskWrites(context: container.mainContext).reschedule(record, to: nil)
        let entry = try #require(try container.mainContext.fetch(FetchDescriptor<OutboxEntry>()).first)
        #expect(String(bytes: entry.body!, encoding: .utf8) == #"{"scheduled_date":null}"#)
        #expect(record.scheduledDay == nil)
    }

    @Test func captureQueuesACreateWithALocalID() throws {
        let record = try TaskWrites(context: container.mainContext).capture(title: "Call the lab", day: "2026-03-07")
        let entry = try #require(try container.mainContext.fetch(FetchDescriptor<OutboxEntry>()).first)
        #expect(record.id.hasPrefix("local-"))
        #expect(entry.kind == "task.create" && entry.method == "POST" && entry.createsLocalID == record.id)
    }

    @Test func anAcceptedCaptureTakesTheServerID() async throws {
        let context = container.mainContext
        let record = try TaskWrites(context: context).capture(title: "Call the lab", day: "2026-03-07")
        let server = try TaskDTO.make(title: "Call the lab")
        let body = String(bytes: try OmakaseJSON.encoder.encode(server), encoding: .utf8)!
        await api.script([.reply(201, body)])
        _ = await OutboxWorker(context: context, api: api, handlers: OutboxHandlers([TaskHandler(context: context)])).drain()
        #expect(record.id == server.id.uuidString)
    }
```

Run them. Expected: compile errors for `kind:`, `handlers:`, `TaskHandler`,
`setKanbanStatus`, `reschedule` and `capture`.

- [ ] **Step 3: Implement.**
  - **`Records.swift`:** add `public var kind: String = "task.patch"` to
    `OutboxEntry`, with the doc comment
    `/// Which OutboxHandler applies the reply. The default keeps M1's queued entries valid (M3.1 spec §3).`
    Its init gains `kind: String = "task.patch"`.
  - **`OutboxHandlers.swift`:**

```swift
import Foundation

/// Applies an accepted write's reply to the store. One per kind of write
/// (M3.1 spec §3), so a new kind is a new small type, not a longer switch.
@MainActor
public protocol OutboxHandler {
    var kinds: [String] { get }
    func apply(_ entry: OutboxEntry, body: Data)
}

/// The handlers the worker looks writes up in.
///
///     OutboxHandlers([TaskHandler(context: ctx), ReviewHandler(context: ctx)])
@MainActor
public struct OutboxHandlers {
    private let byKind: [String: any OutboxHandler]

    public init(_ handlers: [any OutboxHandler]) {
        var byKind: [String: any OutboxHandler] = [:]
        for handler in handlers { for kind in handler.kinds { byKind[kind] = handler } }
        self.byKind = byKind
    }

    public func handles(_ kind: String) -> Bool { byKind[kind] != nil }

    public func apply(_ entry: OutboxEntry, body: Data) { byKind[entry.kind]?.apply(entry, body: body) }
}
```

  - **`OutboxWorker.swift`:**
    - Replace `onAccepted` with `private let handlers: OutboxHandlers`.
    - The init becomes
      `init(context:api:clock: = { .now }, handlers: OutboxHandlers)`.
    - In `accept`, call `handlers.apply(entry, body: body)`.
    - In `drainOnce`, before the due-date check:

```swift
            guard handlers.handles(entry.kind) else {
                // Never send what nothing can apply; never drop it either.
                park(entry, reason: "no handler for write kind \(entry.kind.debugDescription)")
                try? context.save()
                continue
            }
```

  - **`OutboxQueue.swift`:** move `nextSequence()` and
    `hasLaterPendingWrite(than:for:)` out of `TaskWrites` unchanged, and
    add:

```swift
    public func enqueue(
        kind: String, method: String, path: String, body: Data?, subjectID: String?, createsLocalID: String? = nil
    ) throws {
        context.insert(
            OutboxEntry(
                sequence: try nextSequence(), method: method, path: path, body: body, subjectID: subjectID,
                createsLocalID: createsLocalID, kind: kind))
    }
```

  - **`TaskHandler.swift`:** `TaskWrites.applyServerCopy`'s body, moved.
    `kinds` is `["task.patch", "task.create"]`, `apply(_:body:)` is that
    body, and it uses `OutboxQueue.hasLaterPendingWrite`.
  - **`TaskWrites.swift`:** keep the file's doc comment. The writes, each
    followed by `try context.save()`:

```swift
    public func toggleCompletion(_ record: TaskRecord) throws {
        record.isCompleted.toggle()
        // Mirrors Task.save both ways (M3.1 spec, Decisions).
        (record.completedAt, record.kanbanStatus) = record.isCompleted ? (.now, "done") : (nil, "todo")
        try patch(record, body: ["is_completed": record.isCompleted])
    }

    public func setKanbanStatus(_ record: TaskRecord, to status: String) throws {
        record.kanbanStatus = status
        if status == "done" && !record.isCompleted { (record.isCompleted, record.completedAt) = (true, .now) }
        try patch(record, body: ["kanban_status": status])
    }

    public func reschedule(_ record: TaskRecord, to day: String?) throws {
        record.scheduledDay = day
        // An explicit null: `nil` in a synthesized Encodable would be omitted (Review Focus 2).
        let value = day.map { "\"\($0)\"" } ?? "null"
        try patch(record, raw: Data(#"{"scheduled_date":\#(value)}"#.utf8))
    }

    public func capture(title: String, day: String?) throws -> TaskRecord {
        let record = TaskRecord(id: "local-\(UUID().uuidString)", title: title, scheduledDay: day)
        context.insert(record)
        let body = try OmakaseJSON.encoder.encode(CaptureBody(title: title, scheduledDate: day))
        try queue.enqueue(
            kind: "task.create", method: "POST", path: "/api/v1/tasks/", body: body, subjectID: record.id,
            createsLocalID: record.id)
        try context.save()
        return record
    }

    private func patch(_ record: TaskRecord, body: some Encodable) throws {
        try patch(record, raw: try OmakaseJSON.encoder.encode(body))
    }

    private func patch(_ record: TaskRecord, raw: Data) throws {
        try queue.enqueue(
            kind: "task.patch", method: "PATCH", path: "/api/v1/tasks/\(record.id)/", body: raw,
            subjectID: record.id)
        try context.save()
    }

    private struct CaptureBody: Encodable {
        let title: String
        let scheduledDate: String?
    }
```

    `queue` is `OutboxQueue(context: context)`, made in the init. The
    capture body may leave out a nil `scheduled_date`, because on a create
    the server's default is already null.

  - **`AppServices.swift`:**

```swift
        let worker = OutboxWorker(
            context: container.mainContext, api: api,
            handlers: OutboxHandlers([TaskHandler(context: container.mainContext)]))
```

  - **The parent spec**, after the `pending|inFlight|parked` line: add
    `*M3.1:* no \`inFlight\` state: the worker drains serially in one actor, so no second sender can take an entry mid-send.`

- [ ] **Step 4: Update the existing tests' construction.**
  `OutboxWorkerTests` and `TaskWritesTests` build the worker with
  `handlers: OutboxHandlers([TaskHandler(context:)])` in place of
  `onAccepted: writes.applyServerCopy`. Every assertion stays as it is.

- [ ] **Step 5: Pass and run the gate.** OmakaseStore's tests pass,
  including all of M1's outbox tests, and `apps/apple/gate.sh` exits 0.

- [ ] **Step 6: Commit.** Commits:
  - `test(#$KINDS): outbox kinds, unknown kinds park, task writes`
  - `refactor(#$KINDS): OutboxQueue and TaskHandler out of TaskWrites`
  - `feat(#$KINDS): OutboxEntry.kind and handlers by kind`
  - `feat(#$KINDS): kanban, reschedule and capture writes`

  Don't open the PR yet; Task 8 continues on this branch.

---

### Task 8: Subtask, block, session and review writes (`$KINDS`, continued)

**Files:**
- Create in `.../OmakaseStore/`: `SubtaskWrites.swift`, `BlockWrites.swift`,
  `SessionWrites.swift`, `ReviewWrites.swift`. Each file holds its writes and
  its `OutboxHandler`.
- Create: `Tests/OmakaseStoreTests/DayWritesTests.swift`
- Modify: `apps/apple/OmakaseMac/AppServices.swift` (register every handler)

**Interfaces:**
- Consumes: `OutboxQueue`, `OutboxHandler`, and Task 6's records.
- Produces:

```swift
SubtaskWrites(context:).toggle(_ subtask: SubtaskRecord)                  // kind subtask.patch
BlockWrites(context:).saveNotes(_ block: TimeBlockRecord, _ notes: String)  // kind block.patch
BlockWrites(context:).rate(_ block: TimeBlockRecord, _ rating: Int)         // kind block.patch
public struct FinishedSession { taskID: String?; timeBlockID: String?; type: String; minutes: Int; startedAt: Date; endedAt: Date; completed: Bool }
SessionWrites(context:).record(_ session: FinishedSession)                // kind session.create
ReviewWrites(context:).save(day: String, rating: Int?, win: String, energy: Int?, shutdown: Bool)  // kind review.put
SubtaskHandler, BlockHandler, SessionHandler, ReviewHandler: OutboxHandler
```

- [ ] **Step 1: Write the failing tests** in `DayWritesTests.swift`, with the
  same container and fake-API setup.

```swift
    @Test func checkingASubtaskPatchesItUnderItsTask() throws {
        let subtask = SubtaskRecord(dto: try .make(title: "a"), taskID: "t1")
        container.mainContext.insert(subtask)
        try SubtaskWrites(context: container.mainContext).toggle(subtask)
        let entry = try #require(try entries().first)
        #expect(subtask.isCompleted)
        #expect(entry.kind == "subtask.patch" && entry.path == "/api/v1/tasks/t1/subtasks/\(subtask.id)/")
    }

    @Test func notesAndRatingPatchTheBlock() throws {
        let block = TimeBlockRecord(dto: try .make(day: "2026-03-07"))
        container.mainContext.insert(block)
        let writes = BlockWrites(context: container.mainContext)
        try writes.saveNotes(block, "Drafted §2")
        try writes.rate(block, 4)
        #expect(try entries().map(\.kind) == ["block.patch", "block.patch"])
        #expect((block.notes, block.sessionRating) == ("Drafted §2", 4))
    }

    @Test func aSessionPostsTheMacsClockAndItsBlock() throws {
        let started = Date(timeIntervalSince1970: 1_772_874_000)  // 2026-03-07 09:00 UTC
        try SessionWrites(context: container.mainContext).record(
            FinishedSession(taskID: "t1", timeBlockID: "b1", type: "focus", minutes: 25,
                            startedAt: started, endedAt: started.addingTimeInterval(1500), completed: true))
        let entry = try #require(try entries().first)
        let body = String(bytes: entry.body!, encoding: .utf8)!
        #expect(entry.kind == "session.create" && entry.method == "POST")
        #expect(body.contains(#""started_at":"2026-03-07T09:00:00.000Z""#) && body.contains(#""time_block":"b1""#))
    }

    @Test func aSessionOnACapturedTaskSendsTheServerID() async throws {
        // Review Focus 3: the capture's local id is rewritten before the session is sent.
        let context = container.mainContext
        let task = try TaskWrites(context: context).capture(title: "New", day: "2026-03-07")
        try SessionWrites(context: context).record(
            FinishedSession(taskID: task.id, timeBlockID: nil, type: "focus", minutes: 25,
                            startedAt: .now.addingTimeInterval(-1500), endedAt: .now, completed: true))
        let server = try TaskDTO.make(title: "New")
        let created = String(bytes: try OmakaseJSON.encoder.encode(server), encoding: .utf8)!
        await api.script([.reply(201, created), .reply(201, "{}")])
        _ = await OutboxWorker(context: context, api: api, handlers: allHandlers()).drain()
        let sessionBody = String(bytes: await api.sentRequests[1].body!, encoding: .utf8)!
        #expect(sessionBody.contains(server.id.uuidString) && !sessionBody.contains("local-"))
    }

    @Test func aReviewPutsByDateAndKeepsItsLocalRecord() throws {
        try ReviewWrites(context: container.mainContext).save(
            day: "2026-03-07", rating: 4, win: "M3.1", energy: 2, shutdown: true)
        let entry = try #require(try entries().first)
        #expect(entry.kind == "review.put" && entry.method == "PUT")
        #expect(entry.path == "/api/v1/stats/reviews/by-date/2026-03-07/")
        #expect(entry.subjectID == DailyReviewRecord.subjectID(for: "2026-03-07"))
        let record = try #require(try container.mainContext.fetch(FetchDescriptor<DailyReviewRecord>()).first)
        #expect(record.energy == 2 && record.isShutdown)
    }

    @Test func everyKindTheWritesQueueHasAHandler() {
        let handlers = allHandlers()
        for kind in ["task.patch", "task.create", "subtask.patch", "block.patch", "session.create", "review.put"] {
            #expect(handlers.handles(kind), "no handler for \(kind)")
        }
    }
```

The helpers:
- `entries()` fetches `OutboxEntry` sorted by `sequence`.
- `allHandlers()` builds `OutboxHandlers` from all five handlers.
- `SubtaskDTO.make(title:)` decodes a JSON literal.

Run them. Expected: compile errors.

- [ ] **Step 2: Implement**, one file per domain. Each holds a
  `@MainActor public final class …Writes` with an `OutboxQueue`, whose
  writes update the record, enqueue, and save. Each also holds a
  `…Handler: OutboxHandler`.

```swift
// SubtaskWrites.swift
@MainActor
public final class SubtaskWrites {
    private let context: ModelContext
    private let queue: OutboxQueue
    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func toggle(_ subtask: SubtaskRecord) throws {
        subtask.isCompleted.toggle()
        try queue.enqueue(
            kind: "subtask.patch", method: "PATCH", path: "/api/v1/tasks/\(subtask.taskID)/subtasks/\(subtask.id)/",
            body: try OmakaseJSON.encoder.encode(["is_completed": subtask.isCompleted]), subjectID: subtask.id)
        try context.save()
    }
}

/// The server's copy of a subtask replaces the local one, unless a later write is queued.
@MainActor
public final class SubtaskHandler: OutboxHandler {
    public let kinds = ["subtask.patch"]
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(SubtaskDTO.self, from: body) else { return }
        let id = dto.id.uuidString
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [id]),
            let record = try? context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.id == id })).first
        else { return }
        record.apply(dto)
    }
}
```

The other three files follow the same shape:
- **`BlockWrites.saveNotes` and `rate`** PATCH `/api/v1/timeblocks/<id>/`
  with `{"notes":…}` or `{"session_rating":…}`, subject `block.id`.
  `BlockHandler` decodes `TimeBlockDTO` and applies it, with the same
  later-write guard.
- **`SessionWrites.record`** POSTs `/api/v1/pomodoro/sessions/`. It encodes
  a private `SessionBody: Encodable` with the fields `task`, `timeBlock`,
  `sessionType`, `durationMinutes`, `startedAt`, `endedAt` and `completed`.
  The encoder writes snake_case, and ISO-8601 with milliseconds. The subject
  is `nil`, because no local record depends on a session's reply.
  `SessionHandler.apply` does nothing, because sessions aren't cached until
  M3.3 shows history. Its doc comment says so.
- **`ReviewWrites.save`** upserts the `DailyReviewRecord` for `day`, then
  enqueues `review.put`. The method is PUT, the path
  `/api/v1/stats/reviews/by-date/<day>/`, and the body a private
  `ReviewBody` with `productivityRating`, `winOfTheDay`, `energy` and
  `isShutdown`. The subject is `DailyReviewRecord.subjectID(for: day)`.
  `ReviewHandler` decodes `DailyReviewDTO` and applies it to the day's
  record, with the same guard, using the review subject id.

The `SessionBody` and `ReviewBody` nils (`task`, `timeBlock`, `energy`,
`productivityRating`) may be left out: on a create or full PUT, a missing
key means "not set", which is correct. Only `reschedule` needs the
explicit null (Task 7).

In `AppServices.swift`, register all five handlers in the
`OutboxHandlers([...])` list.

- [ ] **Step 3: Pass and run the gate.** OmakaseStore's tests pass,
  `apps/apple/gate.sh` exits 0, and OmakaseStore coverage stays ≥ 90%. If
  `SessionHandler.apply`'s empty body is uncovered, test that applying a
  session reply changes nothing.

- [ ] **Step 4: Run the real stack.**
  - Launch the app against `docker-compose up`, signed in.
  - **Complete a task offline, then go online:** the server has it (M1 step
    5).
  - **Check the review and session kinds by hand**, from a scratch test
    against a `docker-compose` JWT, or by temporarily adding them to a
    debug menu. Either way, run `ReviewWrites.save`, then
    `SessionWrites.record`, then a drain, and `curl` both endpoints to see
    the rows.
  - Paste the results into the PR.

- [ ] **Step 5: Commit and PR.** Commits:
  - `test(#$KINDS): subtask, block, session and review writes`
  - `feat(#$KINDS): subtask writes and handler`
  - `feat(#$KINDS): block notes and rating`
  - `feat(#$KINDS): sessions keep the Mac's clock`
  - `feat(#$KINDS): the review is saved by date`
  - `feat(#$KINDS): the app registers every handler`

  Open a PR with `Closes #$KINDS`, stacked on Task 6's.

---

## Merging

These are the AGENTS.md "Stacked PRs" steps, using `gh pr merge --merge`, one
PR at a time, with CI green:
1. **Tasks 1, 2 and 4** are independent, so merge them in any order.
2. **Task 3**, after Task 2.
3. **Tasks 5 → 6 → 7/8**, in order.

After each merge, close its issue by hand (#83). When all seven are closed,
M3.1 is done: update `docs/ROADMAP.md`'s M3 row to
`M3.1 done (#…); M3.2 Focus next.` in the last PR.

## Deliberately deferred (from the spec)

- Coalescing repeated writes to one item.
- The `inFlight` state (Task 7 notes why).
- Week windows, which M4 builds by reusing `DaySync` per day.
- A local cache of pomodoro sessions (M3.3, when history shows).

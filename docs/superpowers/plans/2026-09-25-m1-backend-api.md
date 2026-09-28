# M1 Backend: the API changes the macOS client needs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Mac client's outbox and sign-in a backend they can rely on:
one strict parser for a client's `?date=`, Google ID tokens accepted from
more than one OAuth client, `Idempotency-Key` on the creates the outbox
replays, and contract fixtures the Swift DTOs decode.

**Architecture:** The date parser lives in the `omakase` project package,
because the apps must stay independent of each other. Idempotency is a new
Django app, `idempotency`, that owns one model and one DRF mixin; the three
create endpoints opt in by adding the mixin. Contract fixtures are written by
a backend test into `apps/apple/Fixtures/`, and that test fails when a
response's shape drifts from its fixture.

**Tech Stack:** Python 3.12.14, Django 5.2.17, DRF 3.17.2, google-auth
2.58.1, pytest, factory-boy. The backend gate is `scripts/gate.sh`.

**Spec:** `docs/superpowers/specs/2026-09-25-macos-client-design.md`
(sections "API changes (backend, M1)" and "Testing and the Apple gate →
Contract fixtures").

## Global Constraints

- The M0 stack (#67 → #68 → #70 → #71) is merged to `develop` before Task 1 starts. Every branch below is cut from `develop`.
- Every task follows AGENTS.md:
  - an issue first, labelled type + `M1` + `area:*`
  - a branch `type/<issue>-<slug>`
  - commits `type(#N): message`
  - test-first
  - `scripts/gate.sh` exits 0 before the PR
  - PR body opens `Closes #N`
- Contract changes (invariant 8) change their tests in the same commit and get a `CHANGELOG.md` line.
- Dates on the wire are `YYYY-MM-DD` exactly (spec, "Data flow → Reads"; AGENTS.md invariant 2).
- `GOOGLE_CLIENT_ID` (single) is still read for one release (spec, "API changes" 1).
- Idempotency records expire after **7 days**. The same key with a different method or path is a **422** (spec, "API changes" 2).
- Idempotent endpoints: `POST tasks/`, `POST pomodoro/sessions/`, `POST stats/reviews/`. PATCH carries the header, and the server ignores it.
- The gate's ratchets never go up. New functions are 4–20 lines, typed, with at most 2 levels of nesting.
- `apps/apple/Fixtures/` is created by Task 4 of this plan. The Apple plan's DTO tests read it.

## Review Focus

1. **A date that `fromisoformat` accepts but the contract doesn't.** In Python 3.12, `date.fromisoformat("20260307")` and `("2026-W10-1")` both succeed, so a client bug that sends the basic or week form would silently be "understood". Expected: 400. Pinned in Task 1, Step 1: `test_rejects_forms_fromisoformat_accepts`.
2. **Two requests with the same key at the same moment.** A retry fired while the first attempt is still running. Expected: exactly one row created, and both responses carry the same body. Pinned in Task 3, Step 1: `test_concurrent_same_key_creates_once`, using `transaction=True` and two threads.
3. **A key reused by a different user.** Keys are client-generated UUIDs, but nothing stops two clients from colliding. Expected: independent, with no replay across users. Pinned in Task 3: `test_same_key_different_user_is_independent`.
4. **A create that fails validation, retried with the same key.** Expected: the stored 400 is replayed, nothing is created, and the outbox parks it as the spec says. Pinned in Task 3: `test_validation_error_is_stored_and_replayed`.
5. **A malformed or huge `Idempotency-Key` header.** Expected: 400 naming the header and the allowed shape, and nothing stored. Pinned in Task 3: `test_rejects_malformed_key`.

---

### Task 0: Issues

**Files:** none.

- [ ] **Step 1: Create the three issues this plan needs** (#69 already exists)

```bash
cd /Users/will/Documents/Projects/omakase
AUD=$(gh issue create --title "feat(M1): accept Google ID tokens from several OAuth clients" \
  --label "feat,area:accounts,area:settings,M1" --body "Spec: docs/superpowers/specs/2026-09-25-macos-client-design.md, API changes 1. The macOS app signs in with its own OAuth client, so /auth/google/ must accept a token whose aud is any configured client. GOOGLE_CLIENT_IDS (comma-separated) replaces GOOGLE_CLIENT_ID, which is still read for one release so the VPS keeps working. Counter-argument: a list widens what the endpoint accepts; every entry is still a client this project owns." | sed 's#.*/##')
IDEM=$(gh issue create --title "feat(M1): Idempotency-Key on the creates the outbox replays" \
  --label "feat,area:tasks,area:pomodoro,area:stats,invariant,M1" --body "Spec: API changes 2. The Mac outbox retries after timeouts, and without a key a retried POST creates twice. A new idempotency app stores (user, key) -> response for 7 days; POST tasks/, pomodoro/sessions/ and stats/reviews/ opt in. Same key with a different method/path is 422. Counter-argument: a new table and a new failure mode (replays of stale 400s) - but a parked 400 is exactly what the outbox expects." | sed 's#.*/##')
FIX=$(gh issue create --title "test(M1): contract fixtures the Swift client decodes" \
  --label "test,area:accounts,area:tasks,area:apple,M1" --body "Spec: Testing -> Contract fixtures. Backend tests write the real response of every endpoint the Mac app uses into apps/apple/Fixtures/ and fail when a response's shape drifts from its fixture, so an API change that breaks the client fails in its own PR." | sed 's#.*/##')
echo "AUD=$AUD IDEM=$IDEM FIX=$FIX"
```

Expected: three issue numbers. **Record them.** Every `#$AUD`, `#$IDEM` and `#$FIX` below means these numbers.

---

### Task 1: One strict parser for a client's date (#69)

**Files:**
- Create: `backend/omakase/client_dates.py`
- Create: `backend/omakase/tests/__init__.py` (empty)
- Create: `backend/omakase/tests/test_client_dates.py`
- Modify: `backend/tasks/views.py` (`today`, `carried_over`)
- Modify: `backend/study/views.py` (`StudyBlockViewSet.carried_over`, `ClassOccurrenceView.get`)
- Modify: `backend/stats/views.py` (`DailyStatsView.get`, `ReviewSummaryView.get`)
- Modify: `backend/tasks/tests/test_views.py` (one regression test)
- Modify: `CHANGELOG.md`, `AGENTS.md` (invariant 2)

**Interfaces:**
- Produces: `omakase.client_dates.parse_client_date(raw: str | None, name: str = "date") -> datetime.date`. It raises `rest_framework.exceptions.ParseError` (400, `{"detail": ...}`).

- [ ] **Step 1: Branch and write the failing tests**

```bash
git checkout develop && git pull --ff-only && git checkout -b refactor/69-client-date-parser
mkdir -p backend/omakase/tests && touch backend/omakase/tests/__init__.py
```

`backend/omakase/tests/test_client_dates.py`:

```python
"""The one parser for a client's ?date= (#69)."""

import datetime

import pytest
from rest_framework.exceptions import ParseError

from omakase.client_dates import parse_client_date


def test_parses_iso_calendar_date():
    assert parse_client_date("2026-03-07") == datetime.date(2026, 3, 7)


@pytest.mark.parametrize("raw", [None, ""])
def test_missing_date_names_the_param(raw):
    with pytest.raises(ParseError, match="date_from param required"):
        parse_client_date(raw, name="date_from")


def test_malformed_date_quotes_the_value_and_the_shape():
    with pytest.raises(ParseError, match=r"date 'not-a-date' is not YYYY-MM-DD"):
        parse_client_date("not-a-date")


@pytest.mark.parametrize("raw", ["20260307", "2026-W10-1", "2026-03-07T00:00", " 2026-03-07"])
def test_rejects_forms_fromisoformat_accepts(raw):
    # Python 3.12's fromisoformat accepts the basic and week forms; the API
    # contract is YYYY-MM-DD only, so a client sending anything else is a bug
    # to surface, not a date to guess at.
    with pytest.raises(ParseError):
        parse_client_date(raw)


def test_rejects_an_impossible_calendar_date():
    with pytest.raises(ParseError, match="2026-02-30"):
        parse_client_date("2026-02-30")
```

Append this to `TestTaskViewSet` in `backend/tasks/tests/test_views.py`, below `test_today_without_date_is_rejected_issue65`:

```python
    def test_today_rejects_basic_iso_form_issue69(self, authenticated_client, user):
        """fromisoformat accepted 20260307; the contract is YYYY-MM-DD (#69)."""
        TaskFactory(scheduled_date=datetime.date(2026, 3, 7), user=user)
        resp = authenticated_client.get("/api/v1/tasks/today/?date=20260307")
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
```

- [ ] **Step 2: Run them and read the failures**

Run: `docker-compose exec -T backend pytest -o addopts="" -q omakase/tests tasks/tests/test_views.py -k "client_dates or issue69"`

Expected: `test_client_dates.py` fails with `ModuleNotFoundError: No module named 'omakase.client_dates'`, and `test_today_rejects_basic_iso_form_issue69` fails with `assert 200 == 400`. That second one is the bug's own reason.

- [ ] **Step 3: Write the parser**

`backend/omakase/client_dates.py`:

```python
"""The one parser for a client's ?date= (#69).

AGENTS.md invariant 2 - "today" is the client's day - had seven enforcement
points written by hand with three different messages, and #65 was one of
them drifting. Every view that reads a day from a query param calls this.

Usage::

    target = parse_client_date(request.query_params.get("date"))
"""

import datetime
import re

from rest_framework.exceptions import ParseError

# Stricter than date.fromisoformat, which in 3.12 also accepts 20260307 and
# 2026-W10-1. The wire format is exactly YYYY-MM-DD.
_CALENDAR_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")


def parse_client_date(raw: str | None, name: str = "date") -> datetime.date:
    """Parse a client-supplied day or raise a 400 naming the param and value."""
    if not raw:
        raise ParseError(f"{name} param required (YYYY-MM-DD).")
    if not _CALENDAR_DATE.fullmatch(raw):
        raise ParseError(f"{name} {raw!r} is not YYYY-MM-DD.")
    try:
        return datetime.date.fromisoformat(raw)
    except ValueError:
        raise ParseError(f"{name} {raw!r} is not YYYY-MM-DD (no such calendar date).") from None
```

- [ ] **Step 4: Run the parser tests**

Run: `docker-compose exec -T backend pytest -o addopts="" -q omakase/tests`
Expected: all 11 pass.

- [ ] **Step 5: Replace the seven hand-written parsers**

Each site keeps its surrounding logic. Only the parsing changes.

`backend/tasks/views.py`: add `from omakase.client_dates import parse_client_date`. In `today`, replace everything from `client_date = request.query_params.get("date")` through the `except ValueError` block with this, keeping the `#65` comment above it:

```python
        target_date = parse_client_date(request.query_params.get("date"))
```

In `carried_over`, replace from `date_str = ...` through its `except` block with:

```python
        target_date = parse_client_date(request.query_params.get("date"))
```

Then delete `from datetime import date` if nothing else uses it (`ruff check` reports F401 if so).

`backend/study/views.py`: add the import. In `StudyBlockViewSet.carried_over`:

```python
        target_date = parse_client_date(request.query_params.get("date"))
```

In `ClassOccurrenceView.get`, replace the two `if not ... / try: ... fromisoformat ... except` blocks with:

```python
        start = parse_client_date(request.query_params.get("date_from"), name="date_from")
        end = parse_client_date(request.query_params.get("date_to"), name="date_to")
```

Keep the `end < start` and 90-day checks below it unchanged.

`backend/stats/views.py`: add the import. In `DailyStatsView.get`, replace the `date_str`/`if`/`try` block with:

```python
        today = parse_client_date(request.query_params.get("date"))
```

In `ReviewSummaryView.get`:

```python
        review_date = parse_client_date(request.query_params.get("date"))
```

- [ ] **Step 6: Run the whole suite and the gate**

Run: `scripts/gate.sh`
Expected: exit 0. Every existing 400 test still passes, because each one asserts the status, not the text. `test_today_without_date_is_rejected_issue65` asserts `"date" in resp.data["detail"]`, and it still passes.

- [ ] **Step 7: Negative control**

Temporarily change `_CALENDAR_DATE` to `r".+"`, run `docker-compose exec -T backend pytest -o addopts="" -q omakase/tests tasks/tests/test_views.py -k "fromisoformat or issue69"`, and confirm 5 failures. Revert, and confirm `git diff backend/omakase/client_dates.py` is empty.

- [ ] **Step 8: Update the docs and commit**

In `AGENTS.md` invariant 2, replace `#69 gives the parsing of ?date= one owner.` with `omakase/client_dates.parse_client_date is the only parser; it accepts YYYY-MM-DD and nothing else.`

Add this under `### Changed` in `CHANGELOG.md`:

```markdown
- **Every `?date=` is parsed one way.** `YYYY-MM-DD` only - `20260307` and
  week dates are now 400 - with one message shape naming the param and the
  value. (#69)
```

```bash
git add backend/omakase/client_dates.py backend/omakase/tests backend/tasks/tests/test_views.py
git commit -m "test(#69): one strict parser for a client's date" -m "Tests for parse_client_date, and a regression test that /tasks/today/?date=20260307 is a 400."
git add backend/tasks/views.py backend/study/views.py backend/stats/views.py
git commit -m "refactor(#69): seven date parsers become parse_client_date" -m "Behaviour change (invariant 8): the basic and week ISO forms that fromisoformat accepted are now 400, and messages name the param and value."
git add AGENTS.md CHANGELOG.md
git commit -m "docs(#69): invariant 2 names its one parser"
git push -u origin refactor/69-client-date-parser
gh pr create --base develop --title "refactor(#69): one strict parser for a client's date" --body "Closes #69 ..."
```

Every commit ends with the session's `Co-Authored-By` and `Claude-Session` trailers. The PR body states what changed, the negative control from Step 7, and the gate result.

---

### Task 2: Accept Google ID tokens from several OAuth clients (#$AUD)

**Files:**
- Modify: `backend/omakase/settings.py:68` (`GOOGLE_CLIENT_ID`)
- Modify: `backend/accounts/views.py:27-41`
- Create: `backend/accounts/tests/fakes.py`
- Create: `backend/omakase/tests/test_settings_google.py`
- Modify: `backend/accounts/tests/test_views.py` (new tests at the end of the Google login class)
- Modify: `.env.example`, `docker-compose.yml` (backend `environment`), `docs/ARCHITECTURE.md`, `CHANGELOG.md`

**Interfaces:**
- Produces: `settings.GOOGLE_CLIENT_IDS: list[str]`; `omakase.settings.google_client_ids(environ: Mapping[str, str]) -> list[str]`; `accounts.tests.fakes.FakeGoogleVerifier`.

- [ ] **Step 1: Confirm google-auth takes a list of audiences**

Run: `docker-compose exec -T backend python -c "import inspect, google.auth.jwt as j; print('list' in inspect.getsource(j.decode))"`

Expected: `True`. `google.auth.jwt.decode` documents `audience (str or list)`, and `verify_oauth2_token` passes its `audience` argument through. If this prints `False`, stop and report it; the plan's approach depends on it.

- [ ] **Step 2: Branch and write the named fake**

```bash
git checkout develop && git pull --ff-only && git checkout -b feat/$AUD-google-audiences
```

`backend/accounts/tests/fakes.py`:

```python
"""Named fakes for accounts' external I/O (AGENTS.md: named fakes, not inline stubs)."""

from dataclasses import dataclass, field


@dataclass
class FakeGoogleVerifier:
    """Stands in for google.oauth2.id_token.verify_oauth2_token.

    Returns ``idinfo`` for any token and records the audience it was asked
    to check, so a test can assert which clients the view accepts.
    """

    idinfo: dict[str, object]
    audiences_seen: list[object] = field(default_factory=list)

    def __call__(self, token: str, request: object, audience: object = None) -> dict[str, object]:
        self.audiences_seen.append(audience)
        return self.idinfo
```

- [ ] **Step 3: Write the failing tests**

`backend/omakase/tests/test_settings_google.py`:

```python
from omakase.settings import google_client_ids


def test_reads_every_client_from_the_list():
    assert google_client_ids({"GOOGLE_CLIENT_IDS": "web.apps, mac.apps ,,"}) == ["web.apps", "mac.apps"]


def test_falls_back_to_the_single_variable_for_one_release():
    assert google_client_ids({"GOOGLE_CLIENT_ID": "web.apps"}) == ["web.apps"]


def test_the_list_wins_over_the_single_variable():
    env = {"GOOGLE_CLIENT_IDS": "mac.apps", "GOOGLE_CLIENT_ID": "web.apps"}
    assert google_client_ids(env) == ["mac.apps"]


def test_nothing_configured_is_an_empty_list():
    assert google_client_ids({}) == []
```

Append to `backend/accounts/tests/test_views.py`, at module level, with these imports added at the top: `from django.test import override_settings` and `from accounts.tests.fakes import FakeGoogleVerifier`:

```python
@pytest.mark.django_db
class TestGoogleAudiences:
    URL = "/api/v1/auth/google/"

    @override_settings(GOOGLE_CLIENT_IDS=["web.apps", "mac.apps"])
    def test_verifies_against_every_configured_client(self, api_client):
        verifier = FakeGoogleVerifier(_google_idinfo())
        with patch(GOOGLE_VERIFY_PATH, new=verifier):
            resp = api_client.post(self.URL, {"credential": "tok"}, format="json")
        assert resp.status_code == 200
        assert verifier.audiences_seen == [["web.apps", "mac.apps"]]

    @override_settings(GOOGLE_CLIENT_IDS=[])
    def test_no_client_configured_is_a_configuration_error(self, api_client):
        with pytest.raises(ImproperlyConfigured, match="GOOGLE_CLIENT_IDS"):
            api_client.post(self.URL, {"credential": "tok"}, format="json")
```

Also add `from django.core.exceptions import ImproperlyConfigured` if it isn't already imported.

- [ ] **Step 4: Run them and read the failures**

Run: `docker-compose exec -T backend pytest -o addopts="" -q omakase/tests/test_settings_google.py accounts/tests/test_views.py -k "Audiences or google_client_ids or falls_back or wins or nothing"`

Expected: `ImportError: cannot import name 'google_client_ids'`, and the view tests fail because the view still passes the single `GOOGLE_CLIENT_ID`.

- [ ] **Step 5: Implement**

In `backend/omakase/settings.py`, replace line 68 (`GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")`) with the following. Add `from collections.abc import Mapping` next to `import os`.

```python
def google_client_ids(environ: Mapping[str, str]) -> list[str]:
    """Every OAuth client whose Google ID tokens this API accepts (#$AUD).

    GOOGLE_CLIENT_IDS is comma-separated: web, macOS, later iOS. The single
    GOOGLE_CLIENT_ID is still read for one release, so an unchanged .env on
    the VPS keeps working. Usage: ``google_client_ids(os.environ)``.
    """
    raw = environ.get("GOOGLE_CLIENT_IDS") or environ.get("GOOGLE_CLIENT_ID", "")
    return [client.strip() for client in raw.split(",") if client.strip()]


GOOGLE_CLIENT_IDS = google_client_ids(os.environ)
```

In `backend/accounts/views.py`, change the start of `GoogleLoginView.post`:

```python
        if not settings.GOOGLE_CLIENT_IDS:
            raise ImproperlyConfigured("GOOGLE_CLIENT_IDS (or GOOGLE_CLIENT_ID) environment variable is required")
```

and the verify call:

```python
            idinfo = id_token.verify_oauth2_token(
                credential,
                google_requests.Request(),
                audience=settings.GOOGLE_CLIENT_IDS,
            )
```

Grep for the old name: `grep -rn "GOOGLE_CLIENT_ID\b" backend --include=*.py`. Any remaining use other than inside `google_client_ids` must move to `GOOGLE_CLIENT_IDS`, including `override_settings(GOOGLE_CLIENT_ID=...)` in existing tests, which becomes `GOOGLE_CLIENT_IDS=[...]`.

- [ ] **Step 6: Run the tests, the gate, and a negative control**

Run: `scripts/gate.sh`. Expected: exit 0.

Negative control: temporarily pass `audience=settings.GOOGLE_CLIENT_IDS[0]` in the view, confirm `test_verifies_against_every_configured_client` fails with `[['web.apps', 'mac.apps']] != ['web.apps']`, then revert.

- [ ] **Step 7: Configuration and docs**

In `docker-compose.yml`'s backend `environment:`, replace `GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID:-}` with:

```yaml
      GOOGLE_CLIENT_IDS: ${GOOGLE_CLIENT_IDS:-${GOOGLE_CLIENT_ID:-}}
```

In `.env.example`, replace the Google block with:

```bash
# Google OAuth - every client whose ID tokens the API accepts, comma-separated:
# the web client ID, then the macOS client ID (an "iOS" type client in Google Cloud)
GOOGLE_CLIENT_IDS=<web-client-id>.apps.googleusercontent.com,<macos-client-id>.apps.googleusercontent.com
```

In `docs/ARCHITECTURE.md` "Data flow", change "verifies it with `google-auth` against `GOOGLE_CLIENT_ID`" to "…against every client in `GOOGLE_CLIENT_IDS`".

Add to `CHANGELOG.md` `### Changed`:

```markdown
- **Google sign-in accepts several OAuth clients.** `GOOGLE_CLIENT_IDS`
  lists them; `GOOGLE_CLIENT_ID` is still read for one release. (#$AUD)
```

- [ ] **Step 8: Commit, push, PR**

```bash
git add backend/accounts/tests/fakes.py backend/omakase/tests/test_settings_google.py backend/accounts/tests/test_views.py
git commit -m "test(#$AUD): the login verifies against every configured client"
git add backend/omakase/settings.py backend/accounts/views.py
git commit -m "feat(#$AUD): GOOGLE_CLIENT_IDS, with GOOGLE_CLIENT_ID read for one release"
git add docker-compose.yml .env.example docs/ARCHITECTURE.md CHANGELOG.md
git commit -m "docs(#$AUD): configure the web and macOS clients"
git push -u origin feat/$AUD-google-audiences && gh pr create --base develop --title "feat(#$AUD): accept Google ID tokens from several OAuth clients" --body "Closes #$AUD ..."
```

---

### Task 3: `Idempotency-Key` on the creates the outbox replays (#$IDEM)

**Files:**
- Create: `backend/idempotency/__init__.py`, `apps.py`, `models.py`, `services.py`, `mixins.py`
- Create: `backend/idempotency/migrations/0001_initial.py` (via `makemigrations`)
- Create: `backend/idempotency/management/__init__.py`, `management/commands/__init__.py`, `management/commands/purge_idempotency_records.py`
- Create: `backend/idempotency/tests/__init__.py`, `tests/test_views.py`, `tests/test_purge.py`
- Modify: `backend/omakase/settings.py` (`INSTALLED_APPS`)
- Modify: `backend/pyproject.toml` (coverage `source`, importlinter `root_packages`)
- Modify: `backend/tasks/views.py`, `backend/pomodoro/views.py`, `backend/stats/views.py` (add the mixin)
- Modify: `docs/ARCHITECTURE.md`, `AGENTS.md` (repository layout), `CHANGELOG.md`

**Interfaces:**
- Produces:
  - `idempotency.mixins.IdempotentCreateMixin`, which a ViewSet puts first in its bases.
  - `idempotency.services.run_once(user: User, key: str, method: str, path: str, perform: Callable[[], Response]) -> Response`
  - `idempotency.services.read_key(request: Request) -> str | None`
  - `idempotency.services.RECORD_TTL = timedelta(days=7)`
  - The response header `Idempotent-Replayed: true` on a replay.
- The Apple plan's outbox relies on this contract:
  - A repeated key returns the first status and body.
  - The same key with a different method or path is 422.
  - A malformed key is 400.

- [ ] **Step 1: Branch, scaffold the app, write the failing tests**

```bash
git checkout develop && git pull --ff-only && git checkout -b feat/$IDEM-idempotency-key
mkdir -p backend/idempotency/tests backend/idempotency/management/commands
touch backend/idempotency/__init__.py backend/idempotency/tests/__init__.py \
      backend/idempotency/management/__init__.py backend/idempotency/management/commands/__init__.py
```

`backend/idempotency/tests/test_views.py`:

```python
"""Idempotency-Key through the real endpoints (#$IDEM)."""

import datetime
import threading
import uuid

import pytest
from django.db import connection
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from conftest import UserFactory
from idempotency.models import IdempotencyRecord
from tasks.models import Task

TASKS = "/api/v1/tasks/"


def _client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


def _post(client: APIClient, key: str, body: dict | None = None, url: str = TASKS):
    return client.post(url, body or {"title": "Buy milk"}, format="json", HTTP_IDEMPOTENCY_KEY=key)


@pytest.mark.django_db
class TestIdempotentCreate:
    def test_same_key_twice_creates_once_and_replays_the_response(self, authenticated_client, user):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key)
        second = _post(authenticated_client, key)
        assert first.status_code == second.status_code == 201
        assert second.data == first.data
        assert second["Idempotent-Replayed"] == "true"
        assert Task.objects.filter(user=user).count() == 1

    def test_different_keys_create_twice(self, authenticated_client, user):
        _post(authenticated_client, str(uuid.uuid4()))
        _post(authenticated_client, str(uuid.uuid4()))
        assert Task.objects.filter(user=user).count() == 2

    def test_no_key_behaves_as_before(self, authenticated_client, user):
        authenticated_client.post(TASKS, {"title": "a"}, format="json")
        authenticated_client.post(TASKS, {"title": "a"}, format="json")
        assert Task.objects.filter(user=user).count() == 2

    def test_same_key_different_path_is_422(self, authenticated_client):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        resp = _post(authenticated_client, key, {"session_type": "focus", "duration_minutes": 25},
                     url="/api/v1/pomodoro/sessions/")
        assert resp.status_code == 422
        assert key in resp.data["detail"] and "/api/v1/tasks/" in resp.data["detail"]

    def test_same_key_different_user_is_independent(self, authenticated_client, user):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        other = UserFactory()
        resp = _post(_client_for(other), key)
        assert resp.status_code == 201
        assert "Idempotent-Replayed" not in resp
        assert Task.objects.filter(user=other).count() == 1

    def test_validation_error_is_stored_and_replayed(self, authenticated_client, user):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key, {"title": ""})
        second = _post(authenticated_client, key, {"title": "now valid"})
        assert first.status_code == second.status_code == 400
        assert second["Idempotent-Replayed"] == "true"
        assert Task.objects.filter(user=user).count() == 0

    @pytest.mark.parametrize("key", ["", "x" * 65, "has space", "semi;colon"])
    def test_rejects_malformed_key(self, authenticated_client, key):
        resp = _post(authenticated_client, key)
        assert resp.status_code == 400
        assert "Idempotency-Key" in resp.data["detail"]
        assert IdempotencyRecord.objects.count() == 0

    def test_expired_record_acts_again(self, authenticated_client, user):
        key = str(uuid.uuid4())
        _post(authenticated_client, key)
        IdempotencyRecord.objects.update(created_at=timezone.now() - datetime.timedelta(days=8))
        resp = _post(authenticated_client, key)
        assert resp.status_code == 201 and "Idempotent-Replayed" not in resp
        assert Task.objects.filter(user=user).count() == 2

    @pytest.mark.parametrize("url,body", [
        ("/api/v1/pomodoro/sessions/", {"session_type": "focus", "duration_minutes": 25}),
        ("/api/v1/stats/reviews/", {"date": "2026-03-07", "productivity_rating": 4}),
    ])
    def test_the_other_outbox_creates_are_idempotent(self, authenticated_client, url, body):
        key = str(uuid.uuid4())
        first = _post(authenticated_client, key, body, url=url)
        second = _post(authenticated_client, key, body, url=url)
        assert first.status_code == 201, first.data
        assert second["Idempotent-Replayed"] == "true" and second.data == first.data

    def test_patch_tolerates_the_header(self, authenticated_client, task):
        resp = authenticated_client.patch(f"{TASKS}{task.pk}/", {"is_completed": True}, format="json",
                                          HTTP_IDEMPOTENCY_KEY=str(uuid.uuid4()))
        assert resp.status_code == 200


@pytest.mark.django_db(transaction=True)
def test_concurrent_same_key_creates_once(user):
    # Review Focus 2: a retry fired while the first attempt still runs. The
    # unique (user, key) index makes the second insert wait for the first
    # transaction, then replay it.
    key, results = str(uuid.uuid4()), []

    def attempt() -> None:
        results.append(_post(_client_for(user), key).status_code)
        connection.close()

    threads = [threading.Thread(target=attempt) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert sorted(results) == [201, 201]
    assert Task.objects.filter(user=user).count() == 1
```

`backend/idempotency/tests/test_purge.py`:

```python
import datetime
import uuid

import pytest
from django.core.management import call_command
from django.utils import timezone

from idempotency.models import IdempotencyRecord


@pytest.mark.django_db
def test_purge_deletes_only_records_older_than_seven_days(user):
    fresh = IdempotencyRecord.objects.create(user=user, key=str(uuid.uuid4()), method="POST",
                                             path="/api/v1/tasks/", status_code=201, response_body={})
    old = IdempotencyRecord.objects.create(user=user, key=str(uuid.uuid4()), method="POST",
                                           path="/api/v1/tasks/", status_code=201, response_body={})
    IdempotencyRecord.objects.filter(pk=old.pk).update(created_at=timezone.now() - datetime.timedelta(days=8))
    call_command("purge_idempotency_records")
    assert list(IdempotencyRecord.objects.values_list("pk", flat=True)) == [fresh.pk]
```

Before running these, check the request bodies against the real serializers: `pomodoro/serializers.py` and `stats/serializers.py`. Adjust the dicts in `test_the_other_outbox_creates_are_idempotent` and `test_same_key_different_path_is_422` to the minimal valid body, because `first.status_code == 201` must hold.

- [ ] **Step 2: Run them and read the failures**

Run: `docker-compose exec -T backend pytest -o addopts="" -q idempotency`

Expected: a collection error, `No module named 'idempotency.models'`.

- [ ] **Step 3: The model and the app**

`backend/idempotency/apps.py`:

```python
from django.apps import AppConfig


class IdempotencyConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "idempotency"
```

`backend/idempotency/models.py`:

```python
"""A stored response per (user, Idempotency-Key) (#$IDEM)."""

from django.conf import settings
from django.core.serializers.json import DjangoJSONEncoder
from django.db import models


class IdempotencyRecord(models.Model):
    """The first response to a keyed create, replayed for 7 days."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    key = models.CharField(max_length=64)
    method = models.CharField(max_length=10)
    path = models.CharField(max_length=255)
    status_code = models.PositiveSmallIntegerField()
    response_body = models.JSONField(encoder=DjangoJSONEncoder, null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "key"], name="idempotency_unique_user_key")]

    def __str__(self) -> str:
        return f"{self.method} {self.path} [{self.key}]"
```

In `backend/omakase/settings.py`, add `"idempotency",` to `INSTALLED_APPS` after the local apps. Then run:

```bash
docker-compose exec -T backend python manage.py makemigrations idempotency
```

Expected: `idempotency/migrations/0001_initial.py` is created.

- [ ] **Step 4: The service and the mixin**

`backend/idempotency/services.py`:

```python
"""Run a keyed create once per (user, key); replay it afterwards (#$IDEM).

The Mac client's outbox cannot tell "the server never got it" from "the
server did it and the reply was lost", so it retries with the same key.
Usage, from IdempotentCreateMixin::

    return run_once(request.user, key, request.method, request.path, perform)
"""

import re
from collections.abc import Callable
from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import APIException, ParseError
from rest_framework.request import Request
from rest_framework.response import Response

from idempotency.models import IdempotencyRecord

HEADER = "Idempotency-Key"
RECORD_TTL = timedelta(days=7)
_KEY_SHAPE = re.compile(r"[A-Za-z0-9-]{1,64}")


def read_key(request: Request) -> str | None:
    """The request's key, None if absent, or a 400 naming the allowed shape."""
    if HEADER not in request.headers:
        return None
    key = request.headers[HEADER]
    if not _KEY_SHAPE.fullmatch(key):
        raise ParseError(f"{HEADER} {key!r} must be 1-64 characters of A-Z, a-z, 0-9 and '-'.")
    return key


def run_once(user, key: str, method: str, path: str, perform: Callable[[], Response]) -> Response:
    """Perform once and store the result, or replay what was stored."""
    # One transaction for claim, perform and store: a concurrent request with
    # the same key blocks on the unique index until this commits, then
    # replays it. Nothing half-done is ever visible.
    with transaction.atomic():
        _forget_expired(user, key)
        record, created = IdempotencyRecord.objects.get_or_create(
            user=user, key=key, defaults={"method": method, "path": path, "status_code": 0}
        )
        if not created:
            return _replay(record, method, path)
        response = _perform_as_response(perform)
        _store(record, response)
        return response


def _perform_as_response(perform: Callable[[], Response]) -> Response:
    # A serializer's ValidationError is raised, not returned. Left to
    # propagate, it would roll the claim back and the 400 would never be
    # stored, so a retry would re-run it. Shaped as DRF's own handler shapes it.
    try:
        return perform()
    except APIException as error:
        body = error.detail if isinstance(error.detail, dict | list) else {"detail": error.detail}
        return Response(body, status=error.status_code)


def _forget_expired(user, key: str) -> None:
    cutoff = timezone.now() - RECORD_TTL
    IdempotencyRecord.objects.filter(user=user, key=key, created_at__lt=cutoff).delete()


def _replay(record: IdempotencyRecord, method: str, path: str) -> Response:
    if (record.method, record.path) != (method, path):
        detail = f"{HEADER} {record.key!r} was first used for {record.method} {record.path}, not {method} {path}."
        return Response({"detail": detail}, status=422)
    return Response(record.response_body, status=record.status_code, headers={"Idempotent-Replayed": "true"})


def _store(record: IdempotencyRecord, response: Response) -> None:
    # A 5xx is not an answer to replay: roll the claim back so a retry acts.
    if response.status_code >= 500:
        transaction.set_rollback(True)
        return
    record.status_code = response.status_code
    record.response_body = response.data
    record.save(update_fields=["status_code", "response_body"])
```

`backend/idempotency/mixins.py`:

```python
"""Opt a ViewSet's create() into Idempotency-Key (#$IDEM).

    class TaskViewSet(IdempotentCreateMixin, viewsets.ModelViewSet): ...
"""

from rest_framework.request import Request
from rest_framework.response import Response

from idempotency.services import read_key, run_once


class IdempotentCreateMixin:
    """create() runs once per key; a request without the header is unchanged."""

    def create(self, request: Request, *args: object, **kwargs: object) -> Response:
        key = read_key(request)
        parent_create = super().create
        if key is None:
            return parent_create(request, *args, **kwargs)
        return run_once(request.user, key, request.method, request.path, lambda: parent_create(request, *args, **kwargs))
```

- [ ] **Step 5: Opt the three endpoints in**

- `backend/tasks/views.py`: add `from idempotency.mixins import IdempotentCreateMixin`, then `class TaskViewSet(IdempotentCreateMixin, viewsets.ModelViewSet):`.
- `backend/pomodoro/views.py`: the same import, then put `IdempotentCreateMixin,` first in `PomodoroSessionViewSet`'s bases.
- `backend/stats/views.py`: the same import, then `class DailyReviewViewSet(IdempotentCreateMixin, viewsets.ModelViewSet):`.

In `backend/pyproject.toml`, add `"idempotency"` to `[tool.coverage.run] source` and to `[tool.importlinter] root_packages`. `test_coverage_measures_every_app` fails without the first. Then add a fifth contract:

```toml
[[tool.importlinter.contracts]]
name = "idempotency depends on no app"
type = "forbidden"
source_modules = ["idempotency"]
forbidden_modules = ["accounts", "tasks", "pomodoro", "study", "stats"]
```

- [ ] **Step 6: The purge command**

`backend/idempotency/management/commands/purge_idempotency_records.py`:

```python
"""Delete idempotency records past their 7-day life (#$IDEM). Run daily."""

from django.core.management.base import BaseCommand
from django.utils import timezone

from idempotency.models import IdempotencyRecord
from idempotency.services import RECORD_TTL


class Command(BaseCommand):
    help = "Delete Idempotency-Key records older than 7 days."

    def handle(self, *args: object, **options: object) -> None:
        cutoff = timezone.now() - RECORD_TTL
        deleted, _ = IdempotencyRecord.objects.filter(created_at__lt=cutoff).delete()
        self.stdout.write(f"deleted {deleted} idempotency record(s) older than {cutoff:%Y-%m-%d %H:%M} UTC")
```

- [ ] **Step 7: Run the tests, the gate, and negative controls**

Run: `docker-compose exec -T backend pytest -o addopts="" -q idempotency` and expect all tests to pass. Then run `scripts/gate.sh` and expect exit 0, with `lint-imports` reporting 5 contracts kept.

Negative controls, each reverted afterwards:
1. Remove `IdempotentCreateMixin` from `TaskViewSet`. Expect `test_same_key_twice_creates_once_and_replays_the_response` to fail with `count() == 2`.
2. Move `response = perform()` and `_store(...)` outside the `with transaction.atomic():` block. Expect `test_concurrent_same_key_creates_once` to fail or flake with two tasks. Run it 5 times: `pytest --count 5` is not installed, so use a shell loop.
3. Remove the `(record.method, record.path) != ...` check. Expect `test_same_key_different_path_is_422` to fail.
4. Replace `_perform_as_response(perform)` with `perform()`. Expect `test_validation_error_is_stored_and_replayed` to fail: the second request creates a task, because the first 400 was raised, rolled back and never stored.

- [ ] **Step 8: Docs, commits, PR**

In `docs/ARCHITECTURE.md`, add an `### idempotency` subsection under "Apps". Cover:
- what it stores and why
- the 7-day TTL and the purge command
- the one-transaction design and why it prevents duplicate creates
- which endpoints opt in

In `AGENTS.md` "Repository layout", add: `idempotency/ Idempotency-Key: one stored response per (user, key), 7 days.` Also add invariant 9:

```markdown
9. **A create the Mac outbox replays is idempotent.** `POST tasks/`,
   `pomodoro/sessions/` and `stats/reviews/` put `IdempotentCreateMixin`
   first in their bases. A new endpoint the outbox writes to does the same,
   or a retried request after a timeout creates the row twice.
```

Add to `CHANGELOG.md` `### Added`, creating the heading if absent:

```markdown
- **`Idempotency-Key` on the creates the Mac client replays.** `POST tasks/`,
  `pomodoro/sessions/` and `stats/reviews/` run once per key and replay the
  first response for 7 days (`Idempotent-Replayed: true`); the same key on a
  different endpoint is 422. `manage.py purge_idempotency_records` clears
  expired records. (#$IDEM)
```

```bash
git add backend/idempotency/tests && git commit -m "test(#$IDEM): Idempotency-Key through the real create endpoints"
git add backend/idempotency backend/omakase/settings.py backend/pyproject.toml && git commit -m "feat(#$IDEM): the idempotency app - one stored response per user and key"
git add backend/tasks/views.py backend/pomodoro/views.py backend/stats/views.py && git commit -m "feat(#$IDEM): tasks, pomodoro sessions and reviews opt in"
git add docs/ARCHITECTURE.md AGENTS.md CHANGELOG.md && git commit -m "docs(#$IDEM): invariant 9 - outbox creates are idempotent"
git push -u origin feat/$IDEM-idempotency-key && gh pr create --base develop --title "feat(#$IDEM): Idempotency-Key on the creates the outbox replays" --body "Closes #$IDEM ..."
```

The first commit is red, because it contains the tests without the app. Say so in its body, as #65's test commit did.

---

### Task 4: Contract fixtures the Swift client decodes (#$FIX)

**Files:**
- Create: `backend/tools/tests/test_contract_fixtures.py`
- Create: `apps/apple/Fixtures/*.json` (written by the test)
- Modify: `docker-compose.yml` (mount the Fixtures directory)
- Modify: `AGENTS.md` (testing instructions)

**Interfaces:**
- Produces: `apps/apple/Fixtures/{auth_google,token_refresh,auth_me,tasks_today,task_patch}.json`. Each file is the real response body, pretty-printed with sorted keys. The Apple plan's `OmakaseAPI` decoding tests load these exact names.

- [ ] **Step 1: Branch and mount the fixtures directory**

```bash
git checkout develop && git pull --ff-only && git checkout -b test/$FIX-contract-fixtures
mkdir -p apps/apple/Fixtures
```

In `docker-compose.yml`'s backend `volumes:`, add this line. It's read-write, because the test writes the files.

```yaml
      - ./apps/apple/Fixtures:/repo/apps/apple/Fixtures
```

Run `docker-compose up -d backend`, then `docker-compose exec -T backend pip install -q -r requirements-dev.txt`.

- [ ] **Step 2: Write the fixture test**

`backend/tools/tests/test_contract_fixtures.py`:

```python
"""Contract fixtures for the Swift client (#$FIX).

Each test calls a real endpoint the Mac app uses and compares the response's
*shape* - keys and JSON types, recursively - with the fixture the Swift DTO
tests decode. A shape change fails here, in the PR that makes it. To accept a
deliberate change, regenerate and commit the fixtures in the same PR:

    docker-compose exec -e WRITE_CONTRACT_FIXTURES=1 backend pytest tools/tests/test_contract_fixtures.py
"""

import datetime
import json
import os
from pathlib import Path
from unittest.mock import patch

import pytest

from accounts.tests.fakes import FakeGoogleVerifier
from conftest import TagFactory, TaskFactory

REPO = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parents[3]))
FIXTURES = REPO / "apps" / "apple" / "Fixtures"
WRITE = os.environ.get("WRITE_CONTRACT_FIXTURES") == "1"


def shape(value: object) -> object:
    """Keys and JSON types, not values: what a decoder depends on."""
    if isinstance(value, dict):
        return {key: shape(item) for key, item in sorted(value.items())}
    if isinstance(value, list):
        return [shape(value[0])] if value else []
    return type(value).__name__


def check_fixture(name: str, body: object) -> None:
    path = FIXTURES / f"{name}.json"
    if WRITE:
        path.write_text(json.dumps(body, indent=2, sort_keys=True, default=str) + "\n")
        return
    assert path.exists(), f"{path} is missing; run with WRITE_CONTRACT_FIXTURES=1 and commit it"
    stored = json.loads(path.read_text())
    assert shape(json.loads(json.dumps(body, default=str))) == shape(stored), (
        f"{name}: the response shape no longer matches {path.name}. If deliberate, regenerate "
        "the fixtures with WRITE_CONTRACT_FIXTURES=1 and update the Swift DTOs in the same PR."
    )


def _body(response) -> object:
    return json.loads(response.content)


@pytest.mark.django_db
class TestContractFixtures:
    def test_auth_google(self, api_client, settings):
        settings.GOOGLE_CLIENT_IDS = ["mac.apps"]
        idinfo = {"email": "ada@example.com", "email_verified": True, "given_name": "Ada", "family_name": "L"}
        with patch("accounts.views.id_token.verify_oauth2_token", new=FakeGoogleVerifier(idinfo)):
            resp = api_client.post("/api/v1/auth/google/", {"credential": "tok"}, format="json")
        assert resp.status_code == 200
        check_fixture("auth_google", _body(resp))

    def test_token_refresh(self, api_client, user):
        from rest_framework_simplejwt.tokens import RefreshToken

        resp = api_client.post("/api/v1/auth/token/refresh/", {"refresh": str(RefreshToken.for_user(user))}, format="json")
        assert resp.status_code == 200
        check_fixture("token_refresh", _body(resp))

    def test_auth_me(self, authenticated_client):
        resp = authenticated_client.get("/api/v1/auth/me/")
        assert resp.status_code == 200
        check_fixture("auth_me", _body(resp))

    def test_tasks_today(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 7), due_date=datetime.date(2026, 3, 9),
                           estimated_minutes=25, project=None, discipline=None)
        task.tags.add(TagFactory(user=user))
        resp = authenticated_client.get("/api/v1/tasks/today/?date=2026-03-07")
        assert resp.status_code == 200
        check_fixture("tasks_today", _body(resp))

    def test_task_patch(self, authenticated_client, user):
        task = TaskFactory(user=user, scheduled_date=datetime.date(2026, 3, 7), due_date=None,
                           estimated_minutes=None, project=None, discipline=None)
        resp = authenticated_client.patch(f"/api/v1/tasks/{task.pk}/", {"is_completed": True}, format="json")
        assert resp.status_code == 200
        check_fixture("task_patch", _body(resp))
```

Before running, open `backend/conftest.py`'s `TaskFactory` and `TagFactory`. Pass explicit values for every nullable field the fixture should show, as the tests above do for `project`, `discipline`, `due_date` and `estimated_minutes`. A field that is sometimes `null` and sometimes a string would make the shape non-deterministic.

- [ ] **Step 3: Run it red, then write the fixtures**

Run: `docker-compose exec -T backend pytest -o addopts="" -q tools/tests/test_contract_fixtures.py`
Expected: 5 failures, each `… .json is missing; run with WRITE_CONTRACT_FIXTURES=1`.

Run: `docker-compose exec -T -e WRITE_CONTRACT_FIXTURES=1 backend pytest -o addopts="" -q tools/tests/test_contract_fixtures.py`, then run it again without the variable.
Expected: 5 passed. `ls apps/apple/Fixtures` shows 5 files.

Open `apps/apple/Fixtures/tasks_today.json` and check three things:
1. It is paginated: `count`, `next`, `previous`, `results`.
2. `scheduled_date` is `"2026-03-07"`.
3. `results[0].tags` is a non-empty list.

- [ ] **Step 4: Negative control**

Temporarily add `"notes"` to `TaskListSerializer.Meta.fields`. Expect `test_tasks_today` to fail with the message naming `tasks_today.json`. Revert, and confirm `git diff backend/tasks/serializers.py` is empty.

- [ ] **Step 5: Gate, docs, commit, PR**

Run `scripts/gate.sh` and expect exit 0.

Add a bullet to AGENTS.md "Testing instructions":

```markdown
- **Contract fixtures.** `tools/tests/test_contract_fixtures.py` writes the
  response of each endpoint the Mac app uses to `apps/apple/Fixtures/` and
  fails when a response's shape drifts. A deliberate API change regenerates
  them (`WRITE_CONTRACT_FIXTURES=1`) and updates the Swift DTOs in the same PR.
```

```bash
git add docker-compose.yml backend/tools/tests/test_contract_fixtures.py apps/apple/Fixtures
git commit -m "test(#$FIX): contract fixtures for the endpoints the Mac app uses"
git add AGENTS.md && git commit -m "docs(#$FIX): how to regenerate the contract fixtures"
git push -u origin test/$FIX-contract-fixtures && gh pr create --base develop --title "test(#$FIX): contract fixtures the Swift client decodes" --body "Closes #$FIX ..."
```

Order: Task 4 depends on Task 2 (`GOOGLE_CLIENT_IDS`, `FakeGoogleVerifier`). Merge Task 2's PR first, or stack Task 4's branch on Task 2's.

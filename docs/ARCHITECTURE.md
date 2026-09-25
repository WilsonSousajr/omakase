# Omakase architecture

Omakase is a planning and focus app for two kinds of work that share one
day: **work** (workspaces, projects, tasks) and **study** (semesters,
disciplines, study blocks, a weekly class timetable). Both are placed on the
same calendar as time blocks, worked in pomodoro sessions, and closed out in
a daily review.

This repository is the **API**: Django 5.2 + Django REST Framework over
PostgreSQL 16. It has no client right now. The Next.js web client was removed
in #62, and the next client is a native macOS app, followed by iOS and
Android. Every rule below is therefore about staying a good API for native
clients that live in the user's timezone and may be offline.

Rules live in `AGENTS.md`. This page describes how things work and why, so
that `AGENTS.md` does not have to.

## Data flow

```
client ── Google ID token ──▶ POST /api/v1/auth/google/ ──▶ google-auth verifies
       ◀── JWT pair + user ──                               get-or-create user
client ── Bearer access token ──▶ /api/v1/<resource>/ ──▶ ViewSet.get_queryset()
                                                            scoped to request.user
client ── ?date=YYYY-MM-DD (its own local day) ──▶ day-shaped endpoints
```

- **Authentication is Google-only.** There is no password, register or
  change-password endpoint. The client obtains a Google ID token, the backend
  verifies it with `google-auth` against every client in `GOOGLE_CLIENT_IDS`,
  gets or creates the user by email (the username comes from the email
  prefix, with collisions handled), backfills the name, and returns a
  simplejwt pair: a 60-minute access token and a 7-day refresh token.
  Refresh tokens can be blacklisted (`token_blacklist` is installed).
- **Every read is user-scoped in `get_queryset()`**, and every write sets the
  owner in `perform_create()`. Ownership is reached through the hierarchy, not
  stored on every row:

  | Model | Owner reached through |
  |---|---|
  | Task, Tag, Workspace, PomodoroSession, Semester, DailyReview | `user` |
  | Project | `workspace.user` |
  | Discipline | `semester.user` |
  | StudyBlock, ClassSchedule | `discipline.semester.user` |
  | TimeBlock | `task.user` **or** `study_block.discipline.semester.user` |

- **"Today" is the client's day.** The backend runs in Docker in UTC. An
  endpoint that answers for a day takes that day from the client as
  `?date=`, because the server's `date.today()` is a different date for part
  of every day in every timezone but UTC (#65).

## Apps

```
backend/
  omakase/    settings, root urls, wsgi. Env-only configuration.
  accounts/   Google login, /me, Profile and UserProfile, signals.
  tasks/      Workspace → Project → Task, Tag, TimeBlock, subtasks, reorder.
  pomodoro/   PomodoroSession.
  study/      Semester → Discipline → StudyBlock, ClassSchedule, class occurrences.
  stats/      read-only aggregation over the others, and DailyReview.
  idempotency/ Idempotency-Key: one stored response per (user, key), 7 days.
```

`stats` reads `tasks`, `study` and `pomodoro`, and nothing reads `stats`. The
other apps do not import each other. #66 enforces this with import-linter.
`idempotency` imports no app; the apps whose creates the Mac outbox replays
import its mixin.

### accounts

- `Profile` (one-to-one with `User`, `avatar_color` hex, default `#a3a3a3`)
  and `UserProfile` (`related_name="user_profile"`: pomodoro durations, daily
  work and study goals, timezone, `week_starts_on`). Both are created by
  `post_save` signals in `accounts/signals.py`. `UserProfileView` still does a
  get-or-create, so users created before the signal existed also get one.
- `MeView` is a `RetrieveUpdateAPIView`. GET returns `UserSerializer`; PATCH
  uses `UpdateProfileSerializer`, a plain `Serializer` because it writes two
  models, `User` and `Profile`, inside `transaction.atomic()`.

### tasks

- Workspace → Project → Task, where a task's project is optional
  (`SET_NULL` when the project is deleted). Workspace and Project responses
  carry `project_count` and `task_count` from `Count` annotations, not stored
  fields.
- `TaskListSerializer` is lightweight and used for lists; `TaskSerializer`
  includes `time_blocks` and is used for detail. `actual_minutes` sums
  `end_time - start_time` over prefetched time blocks in Python, which avoids
  an N+1 query.
- Tags are written as `tag_ids` and read as nested `tags`. `color` must match
  a hex regex.
- `completed_at` is read-only and set on the server when `is_completed`
  changes.
- **TimeBlock** is polymorphic: nullable `task` and nullable `study_block`,
  both `CASCADE`. A `CheckConstraint` requires at least one; the serializer
  requires exactly one and rejects `end_time <= start_time` with a 400 before
  the database constraint is reached. `notes` is free text; `session_rating`
  is 1-5 or null.
- `reorder-bulk/` takes at most 100 items and runs in `transaction.atomic()`
  with `select_for_update()`, so concurrent reorders serialize instead of
  interleaving.
- `carried-over/?date=` returns incomplete tasks scheduled before that day.
  It is what a morning-planning flow reads.
- Shared numbers live in `tasks/constants.py`.

### study

- Semester → Discipline → StudyBlock mirrors Workspace → Project → Task.
  `StudyBlock.save()` keeps `is_completed` and `status` in step, as `Task`
  does. Skipping a study block sets `status="skipped"`; it does not only clear
  `scheduled_date`. The field is `block_type`, not `type`, to avoid shadowing
  a Python builtin.
- **ClassSchedule** is the recurring weekly timetable: `day_of_week` 0-6,
  start and end time, `class_type`, `location`, `is_active`, with a
  `CheckConstraint` for `end_time > start_time` and the day range.
- **Class occurrences are computed, not stored.** `class-occurrences/`
  expands schedules over `date_from..date_to` (both required, at most 90 days),
  inside each semester's dates. Occurrences have composite ids
  `{schedule_id}-{date}` because they are not database rows.

### stats

- `daily/`: hours focused, blocks, streak and weekly hours.
- `review/?date=`: one day's `TimeBlock`, `Task`, `StudyBlock` and
  `PomodoroSession` activity, aggregated.
- `reviews/`: `DailyReview`, unique per `(user, date)`: `productivity_rating`
  1-5, `win_of_the_day`, `is_shutdown`, `shutdown_at`. The serializer checks
  uniqueness from the request context because `user` is not a serializer
  field. `perform_update` stamps `shutdown_at` when `is_shutdown` becomes
  true.
- Rolling work over to another day is a PATCH of `scheduled_date` (tomorrow,
  a chosen date, or `null` for the backlog). No dedicated endpoint exists.

### idempotency

- **What it stores, and why.** `IdempotencyRecord`, unique per `(user, key)`:
  the method, the path, the status code and the response body of the first
  request that carried an `Idempotency-Key` header. The Mac client's outbox
  cannot tell "the server never got it" from "the server did it and the reply
  was lost", so it retries with the same key, and the second request replays
  the first answer (`Idempotent-Replayed: true`) instead of creating twice.
  (#77)
- **The contract.** A key is 1-64 characters of `A-Za-z0-9-`, otherwise 400.
  The same key on a different method or path is 422. A 4xx is stored and
  replayed, because a retry of a rejected create is still rejected. A 5xx is
  not stored, so the retry acts again. A request without the header is
  unchanged.
- **One transaction.** Claiming the key, running the create and storing the
  response happen inside one `transaction.atomic()`. A concurrent request
  with the same key blocks on the unique index until the first commits, then
  replays it, so nothing half-done is ever visible and the row is created
  once.
- **Expiry.** Records live 7 days (`RECORD_TTL`). An expired record is
  deleted when its key is used again, and
  `manage.py purge_idempotency_records` deletes all of them; run it daily.
- **Who opts in.** `POST tasks/`, `pomodoro/sessions/` and `stats/reviews/`,
  by putting `IdempotentCreateMixin` first in their bases (invariant 9). A
  PATCH may carry the header; it is ignored, because a PATCH is naturally
  idempotent.

## API surface

All under `/api/v1/`. Every route needs a Bearer token except `auth/google/`
and `auth/token/refresh/`.

| Route | Methods | Notes |
|---|---|---|
| `auth/google/` | POST | Google ID token in, JWT pair and user out |
| `auth/token/refresh/` | POST | simplejwt refresh |
| `auth/me/` | GET, PATCH | user and profile |
| `auth/profile/` | GET, PATCH | preferences (`UserProfile`) |
| `tasks/` | CRUD | plus `today/`, `carried-over/`, `reorder-bulk/` |
| `tasks/<id>/subtasks/` | list, create | and `…/subtasks/<id>/` for detail |
| `tags/` | CRUD | filter by `area` |
| `timeblocks/` | CRUD | filter by date range |
| `workspaces/` | CRUD | annotated `project_count` |
| `projects/` | CRUD | filter by workspace and status; annotated `task_count` |
| `pomodoro/sessions/` | create, list, patch | |
| `stats/daily/` | GET | |
| `stats/review/` | GET | `date` required |
| `stats/reviews/` | CRUD | one per user and day |
| `study/semesters/` | CRUD | annotated `discipline_count` |
| `study/disciplines/` | CRUD | filter by semester and status; annotated `study_block_count` |
| `study/studyblocks/` | CRUD | plus `carried-over/`; filter by discipline, type and status |
| `study/classschedules/` | CRUD | filter by discipline, class type and `is_active` |
| `study/class-occurrences/` | GET | `date_from` and `date_to` required, at most 90 days |

## Configuration and security

- `.env` is required, and `docker-compose up` fails without it. `SECRET_KEY`
  and `DATABASE_URL` raise `ImproperlyConfigured` if missing; there are no
  insecure fallbacks. `DEBUG` defaults to `False`.
- DRF defaults to `IsAuthenticated` with `JWTAuthentication` and
  `SessionAuthentication`. `auth/google/` overrides with `AllowAny`.
- CORS allows explicit origins only. `CORS_ALLOWED_ORIGINS` still lists
  `localhost:3000`, which is left over from the web client.
- PostgreSQL binds to `127.0.0.1` only.

## Why some rules exist

- **Annotated querysets add an explicit `.order_by()`.** A `Count` annotation
  drops the model's default ordering, and DRF pagination then warns and pages
  unpredictably.
- **A ViewSet without `queryset` registers with `basename`.** DRF derives the
  basename from `queryset`, and user-scoped ViewSets define only
  `get_queryset()`.
- **UUID primary keys everywhere except `User`.** Ids are opaque and safe to
  expose. A client could also generate them, which an offline-capable native
  client would need, but the serializers do not accept a client-supplied id
  today. `User` keeps Django's integer key.

## Read next

- `AGENTS.md`: the rules, invariants and workflow.
- `docs/IDEA.md`: the product vision and full feature specification. Its
  phase list is older than the roadmap.
- `docs/docker.md`: images, compose and the prod build.

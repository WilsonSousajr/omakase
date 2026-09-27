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
  | Holiday | `semester.user` |
  | ClassCancellation | `class_schedule.discipline.semester.user` |
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

`stats` reads `tasks`, `study`, `pomodoro` and `accounts`' `UserProfile`, and
nothing reads `stats`. The other apps do not import each other. #66 enforces this with import-linter.
`idempotency` imports no app; the apps whose creates the Mac outbox replays
import its mixin.

### accounts

- `Profile` (one-to-one with `User`, `avatar_color` hex, default `#a3a3a3`)
  and `UserProfile` (`related_name="user_profile"`: pomodoro durations, daily
  work and study goals, timezone, `week_starts_on`). Both are created by
  `post_save` signals in `accounts/signals.py`. `UserProfileView` still does a
  get-or-create, so users created before the signal existed also get one.
- `UserProfile` also holds two reminder preferences (#127):
  `block_reminder_minutes`, the heads-up before every time block (1-120, or
  null for off; default 5, and a check constraint backs the serializer's
  400), and `shutdown_reminder_time`, a time of day in the user's local time
  (null for off).
- `LogoutView` (`POST auth/logout/`, #223) blacklists the caller's refresh
  token through simplejwt's `token_blacklist` app, via
  `accounts/services.revoke_refresh_token`. It answers 205 for a repeated,
  invalid or foreign token too, so a retried sign-out never fails and the
  reply does not say which it was. Refresh rotation is off, so the refresh
  token lives its full 7 days unless it is revoked here; the access token
  still lives out its 60 minutes.
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
- `remind_at` is a nullable, timezone-aware instant ("remind me at"), written
  through `tasks/` with its UTC offset and returned by every task serializer,
  `today/` and `carried-over/` included (#127).
- **Reminders are data, not jobs.** The server stores the three reminder
  fields and sends no notifications. Each client reads them and schedules
  local notifications, so every client fires the same reminders. "Fired" is
  derived (`remind_at` is in the past); "dismissed" waits for a second client
  (M3.6 spec).
- **TimeBlock** is polymorphic: nullable `task` and nullable `study_block`,
  both `CASCADE`. A `CheckConstraint` requires at least one; the serializer
  requires exactly one and rejects `end_time <= start_time` with a 400 before
  the database constraint is reached. `notes` is free text; `session_rating`
  is 1-5 or null.
- `reorder-bulk/` takes at most 100 items and runs in `transaction.atomic()`
  with `select_for_update()`, so concurrent reorders serialize instead of
  interleaving.
- `tasks/` filters by `project`, `workspace` (through the project) and
  `discipline` with `UUIDFilter`, not `ModelChoiceFilter`: the queryset is
  already the caller's, so a foreign id matches nothing, where a choice
  filter would validate it against every row (#223). `unscheduled=true` is
  the Inbox: no `scheduled_date`, no series template, no skipped occurrence.
- `carried-over/?date=` returns incomplete tasks scheduled before that day.
  It is what a morning-planning flow reads. It returns rows only: series
  templates and skipped occurrences are excluded, and a computed occurrence
  in the past lapses instead of carrying over (#124).
- **Recurring tasks are computed, not stored (#124, M8 design §2).** A
  series is a template `Task` with a one-to-one `TaskRecurrence` (`freq`
  daily/weekly/monthly, `interval` 1-30, `weekdays` for weekly with empty
  meaning the weekday of `starts_on`, `starts_on`, inclusive `until`). The
  template has no `scheduled_date` and is hidden from `today/`,
  `carried-over/` and the workload, but listed by `tasks/` with
  `recurrence` embedded. Weekly intervals count weeks from the Monday of
  `starts_on`; monthly rules skip months without the day, as RFC 5545
  does. The expansion is `tasks/services.py: occurrence_dates`.
- **Only exceptions are rows.** An occurrence becomes a `Task` with
  `series` and `occurrence_date` when something writes to it, through
  `PUT tasks/<id>/occurrences/<date>/`, which gets or creates the row
  under a lock on the template and applies the body in the same
  transaction. `UniqueConstraint(series, occurrence_date)` means there can
  never be two, so the materialize PUT is idempotent by its path and needs
  no `Idempotency-Key`. `scheduled_date` is separate, so a moved occurrence
  keeps its identity; `is_skipped` hides one. A `CheckConstraint` keeps
  `series` and `occurrence_date` set together.
- `tasks/services.py: day_items(user, start, end)` is what `today/`,
  `occurrences/` and `stats/workload/` read: the rows scheduled in the
  range (templates and skipped rows excluded), plus a `VirtualOccurrence`
  for each rule date with no stored (series, date) row, ordered by date. It
  runs nine queries however many series there are. A virtual item is
  serialized from its template with `id: null`, `is_virtual: true`, the
  date as `scheduled_date` and `occurrence_date`, and nothing of its own
  (no subtasks, completion, due date or reminder).
- `PUT tasks/<id>/recurrence/` on a task outside a series copies it into a
  new template, attaches the rule there, and makes the task the first
  occurrence (`occurrence_date` is its `scheduled_date`, or `starts_on`), so
  its blocks, subtasks and completion stay put. On a template or an
  occurrence it replaces the series' rule. `DELETE …/recurrence/?date=`
  sets `until` to the day before the client's date, never later than it
  was; before `starts_on` it leaves `until = starts_on - 1`, an empty
  series, which is why the database allows `until >= starts_on - 1`.
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
- **Rotation (#126).** A semester has `rotation_weeks` (1-4, checked in the
  serializer and the database) and a `rotation_anchor` (null means
  `start_date`). A schedule's `rotation_weeks_on` lists the weeks it runs in;
  empty means every week. The week of a date is
  `((monday(date) - monday(anchor)).days // 7) % rotation_weeks + 1`
  (`study/services.py: rotation_week`), so the anchor's whole week is week 1.
- **Exceptions to the weekly rule are stored; occurrences never are (#125).**
  A `Holiday` is an inclusive date range on a semester, and the expansion
  omits every date inside it. A `ClassCancellation` is unique per
  (schedule, date), and the expansion keeps a cancelled occurrence with
  `is_cancelled: true`, because the calendar shows it struck through. The
  cancel PUT and restore DELETE are idempotent by their path, and a cancel
  on a date the expansion would not produce is a 400. The expansion runs
  three queries whatever the number of schedules: schedules, holidays,
  cancellations.
- **Class occurrences are computed, not stored.** `class-occurrences/`
  expands schedules over `date_from..date_to` (both required, at most 90 days),
  inside each semester's dates. Occurrences have composite ids
  `{schedule_id}-{date}` because they are not database rows, and carry the
  rotation `week` they fall in and `is_cancelled`. The expansion
  is `study/services.py: class_occurrences(user, start, end)`, which the
  view and `stats/workload/` both call (#176).
- **Occurrences are wall-clock, so DST cannot move them (#132).** A class
  is a weekday and two naive `TimeField`s, expanded by `date` arithmetic,
  and returned as a date plus an offset-free time. No instant or offset is
  computed, so neither the server's zone nor a clock change enters. The
  client places the time on its own clock for that date. Checked across
  both of London's 2026 changes by `study/tests/test_dst.py`.

### stats

- `daily/`: hours focused, blocks, streak and weekly hours.
- `review/?date=`: one day's `TimeBlock`, `Task`, `StudyBlock` and
  `PomodoroSession` activity, aggregated.
- `reviews/`: `DailyReview`, unique per `(user, date)`: `productivity_rating`
  1-5, `win_of_the_day`, `is_shutdown`, `shutdown_at`. The serializer checks
  uniqueness from the request context because `user` is not a serializer
  field. `perform_update` stamps `shutdown_at` when `is_shutdown` becomes
  true.
- `workload/?date=`: the day's planned minutes against the goal (#128),
  computed in `stats/services.py: day_workload`. It sums `estimated_minutes`
  over the tasks (from `tasks.services.day_items`, so a series' computed
  occurrence counts) and study blocks scheduled on the day (done or not; items
  carried over count only once rescheduled onto it), adds the minutes of the
  day's class occurrences from `study.services.class_occurrences`, and
  compares the total with `UserProfile`'s work plus study goal hours,
  creating the profile with defaults if it is missing. Items with no
  estimate are counted in `unestimated_count`, so a client can say the total
  is partial.
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
- **Who opts in.** `POST tasks/`, `timeblocks/` (#199), `pomodoro/sessions/`
  and `stats/reviews/`, by putting `IdempotentCreateMixin` first in their bases (invariant 9). A
  PATCH may carry the header; it is ignored, because a PATCH is naturally
  idempotent.

## API surface

All under `/api/v1/`. Every route needs a Bearer token except `auth/google/`
and `auth/token/refresh/`.

| Route | Methods | Notes |
|---|---|---|
| `auth/google/` | POST | Google ID token in, JWT pair and user out |
| `auth/token/refresh/` | POST | simplejwt refresh; 401 for a revoked token |
| `auth/logout/` | POST | `{refresh}` blacklisted; 205, also when already revoked or invalid |
| `auth/me/` | GET, PATCH | user and profile |
| `auth/profile/` | GET, PATCH | preferences (`UserProfile`) |
| `tasks/` | CRUD | plus `today/`, `carried-over/`, `reorder-bulk/`; filter by `project`, `workspace`, `discipline`, `unscheduled` |
| `tasks/occurrences/` | GET | `date_from` and `date_to` required, at most 62 days; rows plus computed occurrences, a plain list |
| `tasks/<id>/occurrences/<date>/` | PUT | materialize one occurrence (201, 200 on replay), body applied at once; a non-occurrence date is a 400 |
| `tasks/<id>/recurrence/` | PUT, DELETE | set the series' rule; DELETE `?date=` ends it the day before (204) |
| `tasks/<id>/subtasks/` | list, create | and `…/subtasks/<id>/` for detail |
| `tags/` | CRUD | filter by `area` |
| `timeblocks/` | CRUD | filter by date range; create is idempotent |
| `workspaces/` | CRUD | annotated `project_count` |
| `projects/` | CRUD | filter by workspace and status; annotated `task_count` |
| `pomodoro/sessions/` | create, list, patch | filter by `started_after` (inclusive) and `started_before` (exclusive), aware ISO-8601 instants, naive is a 400; and by `time_block`. Newest first, `id` breaks ties |
| `stats/daily/` | GET | |
| `stats/review/` | GET | `date` required |
| `stats/reviews/` | CRUD | one per user and day |
| `stats/workload/` | GET | `date` required; planned minutes against the goal |
| `study/semesters/` | CRUD | annotated `discipline_count`; `rotation_weeks` 1-4 |
| `study/disciplines/` | CRUD | filter by semester and status; annotated `study_block_count` |
| `study/studyblocks/` | CRUD | plus `carried-over/`; filter by discipline, type and status |
| `study/classschedules/` | CRUD | filter by discipline, class type and `is_active`; `rotation_weeks_on` within the semester's rotation |
| `study/classschedules/<id>/cancellations/<date>/` | PUT, DELETE | cancel (201, 200 on replay) or restore (204) one occurrence; a non-occurrence date is a 400 |
| `study/holidays/` | CRUD | filter by semester; `end_date >= start_date` |
| `study/class-occurrences/` | GET | `date_from` and `date_to` required, at most 90 days; each has its rotation `week` and `is_cancelled`; holidays omitted |

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

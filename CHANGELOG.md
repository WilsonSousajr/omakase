# Changelog

Notable changes to Omakase. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html). Below 1.0 the API
is not frozen, and a breaking API change is a minor bump.

Each entry names the issues behind it. `docs/ROADMAP.md` carries the reasoning
for each milestone.

## [Unreleased]

### Added

- **`GET /api/health/`** (#243), outside `api/v1`: 200 `{"status": "ok"}`
  when the database answers `SELECT 1`, 503 `{"status": "unavailable"}`
  otherwise. No authentication, and it says nothing else. It is exempt from
  the HTTPS redirect, because the container's probe is plain HTTP.

- **Deploying on Coolify** (#243). The prod image migrates at start
  (`backend/docker-entrypoint.sh`), and `docker-compose.coolify.yml`
  builds it with no published port.

- **Task filters for Projects and the Inbox** (#223). `tasks/` takes
  `?project=`, `?workspace=` (through the task's project), `?discipline=`
  (all UUIDs) and `?unscheduled=true` (no `scheduled_date`, series templates
  and skipped occurrences left out; `false` applies no filter). A foreign or
  unknown id returns an empty page; a malformed one is a 400 naming the
  parameter.

- **Contract fixtures for the library** (#223): workspaces, projects,
  semesters, disciplines, class schedules, holidays, the unscheduled task
  list, and the profile and `me` PATCH replies.

- **Recurring tasks, computed on the server** (#124). A series is a
  template task with a rule: `freq` (daily, weekly or monthly), `interval`
  (1-30), `weekdays` (weekly only, 0=Mon..6=Sun; empty means the weekday of
  `starts_on`), `starts_on` and an inclusive `until`. A monthly rule on day
  N skips months without one. Occurrences are expanded on read for the
  client's dates and never created by clients; only exceptions are rows,
  unique per (series, date).
  - Every task response gains `series`, `occurrence_date`, `is_skipped`,
    `is_virtual` and `recurrence` (the series' rule, or null).
  - `GET tasks/occurrences/?date_from=&date_to=` returns rows and computed
    occurrences over at most 62 days, as a plain list. A missing, malformed,
    backwards or longer range is a 400 naming the values.
  - `PUT tasks/<id>/occurrences/<YYYY-MM-DD>/` materializes one occurrence
    from the template (201, or 200 when it already was) and applies the body
    (any task field, plus `is_skipped`) at once. Idempotent by (series,
    date). A date the rule does not produce is a 400; another user's series
    is a 404.
  - `PUT tasks/<id>/recurrence/` sets the rule. On a task outside a series
    it creates a hidden template copied from the task, and the task becomes
    the first occurrence. On a template or an occurrence it replaces the
    series' rule. The response is the task.
  - `DELETE tasks/<id>/recurrence/?date=YYYY-MM-DD` ends the series the day
    before the client's date (204). Stored occurrences stay.
  - Templates are listed by `tasks/` with their rule, and hidden from
    `today/`, `carried-over/` and `stats/workload/`.

- **Holidays and cancelled classes** (#125). `study/holidays/` is CRUD for
  a semester's holidays (`semester`, `name`, `start_date`, `end_date`, both
  ends inclusive; filter by `?semester=`; an end before the start is a 400).
  `study/class-occurrences/` omits every date inside a holiday.
  `PUT study/classschedules/<id>/cancellations/<YYYY-MM-DD>/` cancels one
  class (201, or 200 when it already was) and `DELETE` on the same path
  restores it (204 either way); both are idempotent by path. A date that is
  not an occurrence of the schedule is a 400. Each occurrence gains
  `is_cancelled`: a cancelled class is returned marked, not omitted.
  `stats/workload/`'s `class_minutes` no longer counts a cancelled class.

- **Week A/B rotation for class schedules** (#126). `study/semesters/`
  gains `rotation_weeks` (1-4, default 1) and `rotation_anchor` (a date whose
  Monday starts week 1; null means `start_date`). `study/classschedules/`
  gains `rotation_weeks_on`, the weeks a class runs in (empty means every
  week). A rotation outside 1-4, a week outside the semester's rotation, a
  non-integer week, or shrinking a rotation below a week a schedule uses is
  a 400 naming the value and the range. `study/class-occurrences/` skips the
  weeks a class does not run in, and each occurrence gains `week`. With the
  default rotation of 1 every occurrence is returned as before, with
  `week: 1`.

- **`POST timeblocks/` is idempotent** (#199). It honours `Idempotency-Key`
  like the other creates the Mac outbox replays, so a retried block create
  books one block.

- **`pomodoro/sessions/` lists by time and by block** (#199).
  `?started_after=` (inclusive) and `?started_before=` (exclusive) take
  ISO-8601 instants with an offset (`2026-09-26T10:00:00-03:00`, or `Z`;
  percent-encode the `+` of a positive offset). A naive or malformed bound is
  a 400 naming the value and the expected shape. `?time_block=<uuid>` keeps
  one block's sessions. The list stays newest first, and now breaks
  `started_at` ties by `id`, so pages are stable.

- **Reminders defined on the server** (#127). `auth/profile/` gains
  `block_reminder_minutes` (the heads-up before every time block, 1-120 or
  null for off, default 5; outside the range is a 400) and
  `shutdown_reminder_time` (a local time of day, null for off). Tasks gain
  `remind_at`, a nullable timezone-aware datetime written through `tasks/`
  and returned by `tasks/`, `tasks/today/` and `tasks/carried-over/`. Each
  client schedules its own notifications from these fields.

- **`GET stats/workload/?date=YYYY-MM-DD`** (#128) gives the day's planned
  minutes against the goal: `task_minutes` and `study_block_minutes` (the
  estimates of what is scheduled on the day, done or not), `class_minutes`
  (the day's class occurrences), `planned_minutes`, `goal_minutes` (work
  plus study goal hours), `over_minutes` (negative when there is headroom)
  and `unestimated_count`. A missing or malformed date is a 400.

- **`PUT stats/reviews/by-date/<YYYY-MM-DD>/`** (#144) creates or updates the
  day's one review with any of `productivity_rating`, `win_of_the_day`,
  `energy` and `is_shutdown`. Idempotent by (user, date), so a replay leaves
  one review and a replayed shutdown keeps its first `shutdown_at`.

- **`energy` on the daily review** (#143, #130): optional, 1-3, in every
  review response; anything else is a 400 naming the value.

- **`Idempotency-Key` on the creates the Mac client replays.** `POST tasks/`,
  `pomodoro/sessions/` and `stats/reviews/` run once per key and replay the
  first response for 7 days (`Idempotent-Replayed: true`); the same key on a
  different endpoint is 422. `manage.py purge_idempotency_records` clears
  expired records. (#77)

### Security

- **Sign-out revokes the refresh token** (#223). `POST auth/logout/`
  (authenticated) takes `{"refresh": "<token>"}`, blacklists it and returns
  205; `auth/token/refresh/` then answers 401 for it. A repeated, invalid or
  another user's token is also 205 and revokes nothing, so a retried
  sign-out never fails. A missing `refresh` is a 400. The access token stays
  valid until it expires (60 minutes).

- **Dependencies past eight known vulnerabilities.** Django 5.2 → 5.2.17,
  Django REST Framework 3.16.0 → 3.17.2, simplejwt 5.4.0 → 5.5.1 - the first
  fixed release of each, found by `pip-audit`. (#64)

### Changed

- **CORS allows no origin unless `CORS_ALLOWED_ORIGINS` names one** (#243).
  The default was the web client's `localhost:3000` and `localhost:3001`.
  The native clients send no `Origin`, and the web client is gone.

- **"Today" includes computed items, and "carried over" excludes lapsed
  ones** (#124, invariant 2). `tasks/today/?date=` now returns, besides the
  rows scheduled on the client's day, each series' occurrence on that day
  that has no row: task-shaped, with `id: null` and `is_virtual: true`. A
  client that requires `id` must skip or store these. `tasks/carried-over/`
  returns rows only, so an untouched occurrence in the past lapses instead
  of piling up; an unfinished stored occurrence still carries over, and
  skipped occurrences and templates never do. `stats/workload/` counts the
  day's computed occurrences.

- **`tasks/today/` and `tasks/carried-over/` embed each task's `subtasks`**
  (#145), ordered, prefetched in one query. The plain `tasks/` list is
  unchanged.

- **Pomodoro sessions keep the client's clock and record their block.**
  `POST pomodoro/sessions/` accepts `started_at` (at most 5 minutes ahead and
  8 days back; still server-stamped when omitted) and an optional
  `time_block` the user owns; `ended_at` may not precede `started_at` (#142).

- **Google sign-in accepts several OAuth clients.** `GOOGLE_CLIENT_IDS`
  lists them; `GOOGLE_CLIENT_ID` is still read for one release. (#76)
- **Every `?date=` is parsed one way.** `YYYY-MM-DD` only - `20260307` and
  week dates are now 400 - with one message shape naming the param and the
  value. (#69)

### Fixed

- **`/tasks/today/` requires `?date=`.** Without it the endpoint answered for
  the server's UTC day, which for a client west of UTC is tomorrow from
  evening on. It now returns 400 `date param required.`, like
  `/tasks/carried-over/`. **Breaking** for any client that omitted the date.
  (#65)

### Removed

- **The Next.js web client.** The repository is the API alone until the
  native macOS client. The compose service, CI jobs, pre-commit hook and env
  vars went with it. (#62)

### Changed

- **The quality gate, after omatty's.** `scripts/gate.sh` runs the same steps
  as CI's `gate` job: ruff with complexity ratchets and naive-date and
  `print()` rules, import-linter contracts, cognitive complexity,
  `manage.py check`, `makemigrations --check`, `pip-audit`, the suite at 90%
  coverage over **all six apps** (previously three), and a C.R.A.P. gate.
  Python is pinned to 3.12.14 in both the image and CI, and every dependency
  is pinned exactly. Tests fail if the gate stops checking. (#66)
- **One agent instruction file.** `AGENTS.md` is canonical and `CLAUDE.md`
  imports it. Descriptions moved to `docs/ARCHITECTURE.md`, and commits,
  issues and PRs follow the `type(#N): message` convention. From a prompt
  audit recorded in `docs/audits/2026-09-24-prompt-audit.md`. (#63)

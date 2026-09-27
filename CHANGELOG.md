# Changelog

Notable changes to Omakase. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html). Below 1.0 the API
is not frozen, and a breaking API change is a minor bump.

Each entry names the issues behind it. `docs/ROADMAP.md` carries the reasoning
for each milestone.

## [Unreleased]

### Added

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

- **Dependencies past eight known vulnerabilities.** Django 5.2 → 5.2.17,
  Django REST Framework 3.16.0 → 3.17.2, simplejwt 5.4.0 → 5.5.1 - the first
  fixed release of each, found by `pip-audit`. (#64)

### Changed

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

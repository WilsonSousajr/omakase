# Changelog

Notable changes to Omakase. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html). Below 1.0 the API
is not frozen, and a breaking API change is a minor bump.

Each entry names the issues behind it. `docs/ROADMAP.md` carries the reasoning
for each milestone.

## [Unreleased]

### Added

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

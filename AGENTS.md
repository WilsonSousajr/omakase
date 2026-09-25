# AGENTS.md — Omakase contributor guide

Single canonical instruction file for AI coding agents in this repository.
`CLAUDE.md` only imports it, so do not duplicate rules there.

## Project overview

Omakase plans and protects two kinds of work that share one day: **work**
(workspaces → projects → tasks) and **study** (semesters → disciplines →
study blocks, plus a weekly class timetable). Both go on one calendar as time
blocks, are worked in pomodoro sessions, and are closed out in a daily review.

This repository is the **API**: Django REST Framework over PostgreSQL. It has
no client today. The Next.js web client was removed in #62; the next client is
a **native macOS app**, and after it native iOS and Android. Judge every API
change as a contract with native clients that run in the user's timezone,
keep their own state, and ship on their own release schedule. A breaking
change there cannot be hot-fixed by redeploying a web bundle.

How the backend works, app by app, is in `docs/ARCHITECTURE.md`. Read it
before changing a model or an endpoint.

## Technology stack

- **Python 3.12** in `python:3.12-slim`, **Django 5.2**, **Django REST
  Framework 3.17**, **PostgreSQL 16**.
- **Auth:** Google ID token verified with `google-auth`, then
  `djangorestframework-simplejwt` (60-minute access, 7-day refresh,
  blacklisting on).
- **Tests:** pytest, pytest-django, factory-boy, pytest-cov.
- **Lint and format:** ruff. **Hooks:** pre-commit.
- **Runtime:** Docker Compose, with two services, `db` and `backend`.

## Repository layout

```
backend/
  omakase/      settings, root urls, wsgi. Configuration comes from env only.
  accounts/     Google login, /me, Profile, UserProfile.
  tasks/        Workspace → Project → Task, Tag, TimeBlock, subtasks.
  pomodoro/     PomodoroSession.
  study/        Semester → Discipline → StudyBlock, ClassSchedule, occurrences.
  stats/        read-only aggregation over the others, and DailyReview.
  conftest.py   factories and client fixtures shared by every app's tests.
docs/           ARCHITECTURE.md, ROADMAP.md, IDEA.md, audits/, superpowers/.
.github/        the CI workflow.
```

One responsibility per app. `stats` reads `tasks`, `study` and `pomodoro`;
nothing reads `stats`, and the other apps do not import each other.

## Build and test commands

Run the gate before claiming a change is ready. CI runs the same steps:

```bash
docker-compose exec backend ruff format --check .
docker-compose exec backend ruff check .
docker-compose exec backend python manage.py migrate --noinput
docker-compose exec backend pytest --cov --cov-report=term-missing --cov-fail-under=60
```

Dev dependencies are installed at runtime, not baked into the image. After
rebuilding the container, run
`docker-compose exec backend pip install -r requirements-dev.txt`.

Use `docker-compose` with a hyphen. The spaced `docker compose` form is not
available on this machine.

Tests never call Google or the network. Today they patch
`accounts.views.id_token.verify_oauth2_token` inline. New tests use a named
fake (see Testing instructions).

**The gate is necessary, not sufficient.** It proves units, not the wiring
between them. A change to an endpoint's contract is also exercised against
the running stack (`docker-compose up`, then the endpoint with a real JWT)
before the PR says it works.

## Code style guidelines

- **Functions 4–20 lines.** A longer function does more than one thing, so
  split it.
- **Files under 500 lines.** A longer file means the app boundary is wrong.
- One thing per function, one responsibility per module.
- **Names are specific and unique.** A good name returns fewer than 5 grep
  hits in this repo. Avoid `data`, `handler`, `util`, `helper`, `info`, `obj`.
  Django's own names (`Manager`, `Meta`, `objects`) are the framework's and
  are exempt.
- **New and changed functions carry type annotations.** Parse untyped input
  (request bodies, query params) into typed values at the edge, once.
- **No duplication.** Extract shared logic.
- **Early returns; at most 2 levels of indentation inside a function.**
- **Exception and error messages carry the offending value and the expected
  shape**, for example `f"date {raw!r} is not ISO-8601 (YYYY-MM-DD)"`, never a
  bare `"Invalid input."`.
- **Views are thin: parse, call, respond.** New business logic goes in
  `<app>/services.py`, not in a view or a serializer. Serializers own shape
  and validation, and models own fields, constraints and simple `save()`
  invariants. The existing views that hold logic (`tasks/views.py`
  `reorder_bulk`, the `stats` aggregations) are moved when they are next
  changed, not all at once.
- Match the surrounding file's conventions. Make small, scoped,
  behaviour-preserving changes, with no opportunistic refactors and no
  speculative abstractions.
- Formatting is `ruff format`'s business, so don't discuss style beyond it.

## Comments

- **Keep existing comments.** Do not strip them in a refactor; they carry
  intent and provenance you do not have.
- Write **why, not what**.
- Docstrings on public functions and classes give intent plus one usage
  example.
- When a line exists because of a specific bug or upstream constraint,
  reference the issue number or commit SHA.

## Dependencies

- **Inject through constructor or parameter.** No module-level mutable state
  and no import-time side effects beyond Django's own registration.
- **Wrap third-party libraries behind a thin interface this project owns.**
  `google-auth` is reached only from `accounts`.
- Before adding a dependency, check that the project does not already have
  the capability. Pin every dependency exactly in `requirements*.txt`.

## Logging

- **Structured JSON** for diagnostics and observability.
- **Plain text** only for user-facing management-command output.

## Cross-cutting invariants (do not violate)

1. **Every read is scoped to `request.user` in `get_queryset()`, and every
   write sets the owner in `perform_create()`.** Ownership is reached through
   the hierarchy (the table is in `docs/ARCHITECTURE.md`). A queryset that
   forgets it leaks another user's data, and no test that uses a single user
   will notice.
2. **"Today" is the client's day, sent as `?date=YYYY-MM-DD`.** The backend
   runs in UTC. `date.today()` on the server is a different date for part of
   every day in every other timezone, and native clients are in the user's
   timezone by definition (#65).
3. **Anything that can be a 400 is rejected in the serializer**, before a
   database constraint turns it into a 500. The constraint stays as the
   safety net (TimeBlock: `end_time > start_time`; exactly one of `task` and
   `study_block` in the serializer, at least one in the database).
4. **Annotated querysets add an explicit `.order_by()`.** A `Count`
   annotation drops the model's default ordering, and DRF pagination then
   pages unpredictably.
5. **A ViewSet without `queryset` is registered with `basename`**, because
   DRF cannot derive one from `get_queryset()`.
6. **Bulk writes are bounded and locked.** `reorder-bulk/` caps a request at
   100 items and runs in `transaction.atomic()` with `select_for_update()`.
   New bulk endpoints follow the same pattern.
7. **Configuration comes from the environment with no insecure fallback.** A
   missing `SECRET_KEY` or `DATABASE_URL` raises `ImproperlyConfigured`, and
   `DEBUG` defaults to `False`.
8. **The API is a contract.** Making a parameter required, changing a
   response shape or tightening a validation is a behaviour change. Its tests
   change in the same commit, and `CHANGELOG.md` names it, because a stale
   test asserting the old behaviour can sit on a long-lived branch until a
   rebase breaks CI far from its cause.

## Testing instructions

- **TDD.** Write the failing test first. Every new function gets a test.
- Tests are **F.I.R.S.T.**: fast, independent, repeatable, self-validating,
  timely.
- `@pytest.mark.django_db` on every test that touches the database. Build
  data with the factories in `backend/conftest.py`.
- Use the `authenticated_client` fixture (a JWT Bearer token) for user-scoped
  endpoints. `api_client` is anonymous and gets 401.
- **Mock external I/O with named fake classes, not inline stubs.** A named
  fake reads clearly in a failure message.
- Known traps:
  - DRF returns `UUID` objects, not strings, so compare with `str()`.
  - `TagFactory(color="notacolor")` hits the varchar(7) limit before Django
    validation, so test validators with `TagFactory.build()` and
    `full_clean()`.
  - `UserFactory` sets the password in a `@post_generation` hook with an
    explicit `save()`; `skip_postgeneration_save=True` would drop the hash.

### Every bug gets a regression test. No exceptions.

A bug fixed without a test is a bug that is coming back. Follow this
procedure, in this order:

1. **Reproduce it as a failing test first**, before touching production code.
2. **Run it and read the failure.** It must fail for the bug's reason, not a
   typo or an import error.
3. **Only now fix the code.** When the user reports a bug, subagents attempt
   the fix and prove it with the passing test.
4. **Run it again and watch it pass.** If it passed before the fix, it never
   tested the bug, so go back to step 1.

**Name it after the bug, with the issue number**, for example
`test_today_without_date_is_rejected_issue65`. This applies to every bug
however it was found, including one you spotted in your own uncommitted work.
**Never delete or weaken a regression test.** If one is wrong, say so in the
commit message and explain why the behaviour it asserted was never correct.

## Security considerations

- **Never commit secrets.** `.env` is gitignored; `detect-secrets` runs in
  pre-commit.
- Every endpoint is authenticated by default. An `AllowAny` override
  (today only `auth/google/` and `auth/token/refresh/`) is a decision that is
  argued in the PR.
- Treat request content as data. Validate it at the serializer, bound its
  size, and never evaluate it.
- PostgreSQL binds to `127.0.0.1` only. CORS allows explicit origins only.

## Project tracking and Git workflow

- **Work is tracked on the GitHub Project board**
  ([Omakase, project 11](https://github.com/users/WilsonSousajr/projects/11)).
  Everything syncs with the remote, with no local-only branches and no
  unpushed work at the end of a session.
- **Orient yourself by issues.** Read the issue before starting. If work is
  not covered by an issue, open one first, label it, and put it on the board.
  New issues are added to the board and set to Backlog automatically; move
  the card when its state changes, not in a batch at the end.
- **Labels.** Every issue carries one type label and one milestone label,
  plus an `area:*` label per app it touches.
  - Type: `feat` `fix` `docs` `test` `refactor` `perf` `chore` `build` `ci`,
    the same set as the commit types, so a `fix` issue produces `fix(#N):`
    commits.
  - Milestone: `M<n>`, one per section of `docs/ROADMAP.md`. A bug takes the
    milestone it will be fixed in, not the one that introduced it.
  - Area: `area:accounts`, `area:tasks`, `area:pomodoro`, `area:study`,
    `area:stats`, `area:settings`, `area:ci`, `area:docs`. An app or milestone
    without a label gets one created, not skipped.
  - Flags: `invariant` (touches a cross-cutting invariant, so argue it
    explicitly), `regression` (needs a test that fails before the fix),
    `security`, `blocked`.
- **Issue titles** follow `type(M<n>): what is wrong or what is added`. The
  body says why the issue exists, what was measured or observed, what changes,
  and the counter-argument the PR must answer.
- **Branches** are `type/<issue>-<slug>`, for example
  `fix/65-today-server-date`. Branch from `develop`.
- **Commits are atomic.** One logical change per commit, committed as you go,
  never a catch-all.
- **Commit messages** follow `type(#issue): message`, in the imperative, with
  a subject under 72 characters, for example
  `fix(#65): reject /tasks/today/ without a date` or
  `test(#65): today without ?date= must be a 400`. The body says why.
- **PR titles use the same pattern.** The body opens with `Closes #N` and
  states what changed, why, and how it was verified: which tests were written
  first, which negative controls were run, and what was exercised against the
  running stack.
- **PR evaluation:** report pros, cons and a recommended fix, then ask for
  approval before merging or pushing changes to someone's PR.
- **Merge with `gh pr merge --merge`**, never `--squash`, for an atomic
  history. Squashing collapses the commits and breaks per-commit `git blame`
  and revert.
- **Bulk issue creation, relabelling or board edits affect shared state and
  are hard to undo.** Confirm the structure before looping `gh`.

### Branches and releases

`develop` is where work lands. `main` is what a release is. Nothing is merged
straight to `main`. It moves only by a **promotion**: a PR from `develop` to
`main`, merged with a merge commit and never fast-forwarded, because the merge
commit records what was released and when. Before the merge, the promoting PR
updates `CHANGELOG.md`. After it, the merge commit is tagged
`vMAJOR.MINOR.PATCH`. **No version bump and no release tag without explicit
approval.**

## Worktrees and local environment

- Use `.worktrees/<branch>` for isolated work (gitignored). The Claude Code
  harness keeps its own under `.claude/worktrees/`; don't conflate the two.
  Each worktree needs its own `.env`, copied from the main checkout.
- **Remove a worktree as soon as its branch is merged, abandoned or has a PR
  open**, with `git worktree remove`.
- If `git worktree add` is interrupted, the index ends up with every file
  both `D` and `??`. Don't repair it; `git worktree remove --force` and
  recreate.
- To dry-run a merge of a stale branch, `git merge-tree --write-tree <base>
  <branch>` merges to a tree object without touching anything. Only
  `Auto-merging` lines means the merge is clean.
- To run a worktree's stack beside another, put a gitignored
  `docker-compose.override.yml` in the worktree that remaps ports, and pass
  `-p <name>`. Use `ports: !override` to replace the base list;
  `ports: !reset` only clears it. Compose's default merge unions lists, which
  binds both ports.

## Documentation map

- `docs/ARCHITECTURE.md`: data flow, ownership chains, per-app behaviour and
  the API surface. Read it before the code.
- `docs/ROADMAP.md`: milestones, what is in each and why. Read it before
  proposing a feature.
- `docs/IDEA.md`: the full product vision and feature specification.
- `docs/superpowers/specs/` and `docs/superpowers/plans/`: the design and plan
  behind each milestone's work. Kept after completion as the design record.
- `docs/audits/`: prompt and quality audits, with their findings.
- `docs/docker.md`: images, compose, the prod build.
- `CHANGELOG.md`: what each release changed, with the issues behind it.

**When a rule would help most future sessions, write it here with its
reason.** A description of how something works goes in
`docs/ARCHITECTURE.md` instead. One session's workaround is not a rule.

# Omakase

Productivity app (Notion + Sunsama + Focusbrew). Work + Study modules.

## Architecture

- **Backend**: Django 5.2 + Django REST Framework 3.16 + PostgreSQL 16
- **Infrastructure**: Docker Compose (2 services: db, backend)
- **Frontend**: none — the Next.js client was removed (branch `chore/remove-frontend`); recover from git history if needed

## Quick Start

```bash
docker compose up          # Start all services
docker compose up -d       # Start detached
docker compose down        # Stop all services
docker compose logs -f     # Follow logs
```

Services: backend :8000 | postgres :5432

### Pre-commit Setup

```bash
pip install pre-commit     # Install pre-commit binary
pre-commit install         # Install git hooks
```

Pre-commit runs automatically on `git commit`: ruff lint/format for Python, detect-secrets, and standard file checks.

## Docker Builds

The backend Dockerfile uses a multi-stage build with `dev` and `prod` targets:

```bash
# Dev (default — used by docker-compose up)
docker-compose up                    # targets dev stage, bind mounts for hot reload

# Production builds
docker build --target prod -t omakase-backend:prod ./backend

# Production via compose override
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

- **Backend prod** runs as non-root `django` user (UID 1001). Includes `collectstatic`
- **`.dockerignore`** excludes build artifacts and IDE files from the build context. Backend keeps test files in context because the dev stage needs them at build time.

## Backend Commands

```bash
docker compose exec backend python manage.py makemigrations
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py shell
```

## Project Structure

```
backend/
  accounts/        # Auth: Google OAuth login, me endpoint, Profile model, user preferences
  omakase/         # Django project settings, urls, wsgi
  tasks/           # Task, Tag, TimeBlock, Workspace, Project models + API
  pomodoro/        # PomodoroSession model + API
  study/           # Semester, Discipline, StudyBlock, ClassSchedule models + API
  stats/           # Daily stats aggregation + DailyReview model + ReviewSummaryView
```

## API Endpoints (all under /api/v1/)

- `auth/google/` — POST Google OAuth login (AllowAny, verifies Google ID token, returns JWT + user)
- `auth/token/refresh/` — POST JWT refresh (AllowAny)
- `auth/me/` — GET/PATCH current user + profile (IsAuthenticated)
- `auth/profile/` — GET+PATCH user preferences (IsAuthenticated, get_or_create for existing users)
- `tasks/` — CRUD + `today/` + `carried-over/` + `reorder-bulk/` (user-scoped)
- `tags/` — CRUD, filterable by area (user-scoped)
- `timeblocks/` — CRUD, filterable by date range (user-scoped via task.user OR study_block.discipline.semester.user)
- `workspaces/` — CRUD (user-scoped, annotated with project_count)
- `projects/` — CRUD, filterable by workspace/status (user-scoped via workspace.user, annotated with task_count)
- `pomodoro/sessions/` — Create, list, patch (user-scoped)
- `stats/daily/` — GET daily stats (hours focused, blocks, streak, weekly hours)
- `stats/review/` — GET review summary for a date (date param required, aggregates TimeBlock/Task/StudyBlock/PomodoroSession)
- `stats/reviews/` — CRUD DailyReview (user-scoped, unique per user+date)
- `study/semesters/` — CRUD (user-scoped, annotated with discipline_count)
- `study/disciplines/` — CRUD, filterable by semester/status (user-scoped via semester.user, annotated with study_block_count)
- `study/studyblocks/` — CRUD + `carried-over/`, filterable by discipline/type/status (user-scoped via discipline.semester.user)
- `study/classschedules/` — CRUD, filterable by discipline/class_type/is_active (user-scoped via discipline.semester.user)
- `study/class-occurrences/` — GET computed virtual class occurrences for a date range (date_from, date_to params required, max 90 days)

## Security & Configuration

- `.env` file is **required** — `docker compose up` will fail without it. Copy `.env.example` and fill in real values.
- `SECRET_KEY` and `DATABASE_URL` raise `ImproperlyConfigured` if missing (no insecure fallbacks)
- `DEBUG` defaults to `False` (must explicitly set `DJANGO_DEBUG=True` in `.env` for development)
- DRF uses `IsAuthenticated` permission by default; `JWTAuthentication` + `SessionAuthentication` configured
- JWT: 60-min access tokens, 7-day refresh tokens (djangorestframework-simplejwt)
- Google OAuth: client sends Google ID token → Backend verifies via `google-auth` → Issues JWT pair
- `GOOGLE_CLIENT_ID` env var required for Google login (validated at runtime in GoogleLoginView)
- Auth endpoint (google/) uses explicit `AllowAny` override
- CORS only allows explicit origins (no `CORS_ALLOW_ALL_ORIGINS`)
- PostgreSQL port bound to `127.0.0.1` only (not exposed to network)
- `reorder-bulk` endpoint capped at 100 items per request; uses `transaction.atomic()` + `select_for_update()` for race condition safety
- Pre-commit hooks configured (`.pre-commit-config.yaml`): ruff lint/format, detect-secrets, trailing-whitespace, no-commit-to-branch
- `rest_framework_simplejwt.token_blacklist` in INSTALLED_APPS — enables refresh token blacklisting
- No password auth — all authentication via Google OAuth (no register, login, or change-password endpoints)

## Key Patterns

- UUIDs as primary keys on all models (except User which uses Django's built-in int PK)
- All models have `user` FK (nullable during migration phase) — ViewSets enforce user scoping via `get_queryset()` + `perform_create()`
- When removing `queryset` from ViewSet, must add `basename` to `router.register()` — DRF can't auto-detect
- `TaskListSerializer` (lightweight) for list views, `TaskSerializer` (full with time_blocks) for detail
- Tags: accept `tag_ids` on write, return nested `tags` on read
- `completed_at` is read-only — set server-side when `is_completed` changes
- Shared constants in `backend/tasks/constants.py` — avoid magic numbers
- Tag model `color` field validated with hex color regex
- `TimeBlockSerializer.validate()` rejects `end_time <= start_time` at serializer level (400, not DB IntegrityError)
- Workspace/Project hierarchy: Workspace → Project → Task (optional). Project scoped via `workspace.user`. Task has nullable `project` FK (SET_NULL on delete)
- Annotated querysets (Count) must add explicit `.order_by()` — annotations lose model-level ordering, causing DRF pagination warnings
- Workspace/Project serializers include computed `project_count`/`task_count` via annotation (not DB field)
- Stats app: DailyStatsView (read-only aggregation) + DailyReview model + ReviewSummaryView + DailyReviewViewSet
- Study hierarchy: Semester → Discipline → StudyBlock (parallels Workspace → Project → Task)
- Discipline scoped via `semester.user`, StudyBlock via `discipline.semester.user` (same pattern as Project → workspace.user)
- StudyBlock.save() syncs `is_completed ↔ status` (mirrors Task pattern)
- TimeBlock polymorphic FK: nullable `task` + nullable `study_block`, CASCADE on delete, CheckConstraint requires at least one non-null
- TimeBlockSerializer validates exactly one of task/study_block on write
- TimeBlockViewSet uses Q(task__user) | Q(study_block__discipline__semester__user) with .distinct()
- `block_type` field name (not `type`) to avoid Python reserved word conflict
- ClassSchedule: recurring weekly class blocks (discipline FK, day_of_week 0-6, start/end_time, class_type, location, is_active)
- ClassSchedule CheckConstraint: end_time > start_time, day_of_week 0-6
- ClassOccurrenceView computes virtual occurrences on-the-fly (not persisted) for a date range, respects semester boundaries
- Class occurrence composite IDs: `{schedule_id}-{date}` (since they're not DB rows)
- ClassOccurrenceView: max 90-day range, requires both date_from and date_to params
- DailyReview in stats app — stores productivity_rating (1-5), win_of_the_day, is_shutdown + shutdown_at
- DailyReview unique_together (user, date) — serializer validates via request context since user not in serializer fields
- DailyReviewViewSet.perform_update auto-stamps shutdown_at when is_shutdown transitions to True
- ReviewSummaryView aggregates TimeBlock, Task, StudyBlock, PomodoroSession data for any given date
- Rollover = PATCH scheduled_date on tasks/study blocks (tomorrow, pick date, or null for backlog)
- Study block "skip" action sets status="skipped" (not just clearing scheduled_date)
- Profile model: OneToOneField to User, auto-created via `post_save` signal in `accounts/signals.py`
- Profile: `avatar_color` (hex, default `#a3a3a3`), `created_at`, `updated_at`
- MeView: `RetrieveUpdateAPIView` — GET returns `UserSerializer`, PATCH uses `UpdateProfileSerializer` (writes to both User and Profile)
- UpdateProfileSerializer: plain Serializer (not ModelSerializer) because it writes to two models (User + Profile), wrapped in transaction.atomic()
- GoogleLoginView: POST `/auth/google/`, verifies Google ID token via `google-auth`, gets-or-creates user by email, backfills name from Google profile, issues JWT pair. Username auto-generated from email prefix (handles collisions)
- UserProfile: OneToOne with User (related_name="user_profile"), auto-created via post_save signal. View uses get_or_create for existing users
- UserProfile stores pomodoro durations, daily goals (work/study hours), timezone, week_starts_on

## Plan ↔ Focus Mode Sync

- Creating a time block in plan mode auto-sets `scheduled_date` so the task appears in focus mode's kanban (`/tasks/today/` filters by `scheduled_date`)
- Moving a time block to a different day syncs the parent task/study block's `scheduled_date` to match
- `/tasks/today/` accepts optional `?date=` query param — clients send their local date to avoid server UTC mismatch
- TimeBlock model has `notes` (TextField, blank, default "") and `session_rating` (PositiveSmallIntegerField, null, 1-5 validated)
- `actual_minutes` computed via SerializerMethodField + `prefetch_related("time_blocks")` — avoids N+1, sums (end_time - start_time) in Python
- `/tasks/carried-over/?date=` returns incomplete tasks scheduled before the given date (used by Morning Plan wizard)
- `/study/studyblocks/carried-over/?date=` same pattern, excludes completed/skipped study blocks

## Testing

### Backend (pytest + pytest-django + factory-boy)

```bash
# Run all backend tests (inside Docker)
docker compose exec backend pytest -v
docker compose exec backend pytest --cov --cov-report=term-missing

# Run specific test groups
docker compose exec backend pytest tasks/tests/test_models.py -v
docker compose exec backend pytest tasks/tests/test_views.py -v
docker compose exec backend pytest pomodoro/ -v

# Install dev deps (after rebuilding container)
docker compose exec backend pip install -r requirements-dev.txt
```

**Config:** `backend/pyproject.toml` — pytest settings + coverage config
**Factories:** `backend/conftest.py` — TagFactory, TaskFactory, TimeBlockFactory, PomodoroSessionFactory, SemesterFactory, DisciplineFactory, StudyBlockFactory
**Test files:** `backend/{accounts,tasks,pomodoro,study,stats}/tests/test_{models,serializers,views}.py`

### CI Pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on push to main/develop and PRs:
- **Backend job:** PostgreSQL service → pip install → `ruff check` + `ruff format --check` → migrate → pytest with `--cov-fail-under=60`
- **Docker lint job:** hadolint on the backend Dockerfile (catches anti-patterns)
- **Docker build job:** builds the backend prod image
- **Concurrency:** `ci-${{ github.ref }}` group with `cancel-in-progress: true` — prevents wasted CI minutes on rapid pushes

### Test Patterns

- Backend: `@pytest.mark.django_db` on all DB-touching tests, factory-boy for test data
- **Bug fix tests are mandatory** — every bug fix MUST include a regression test that reproduces the bug (fails without the fix, passes with it). This prevents the same bug from recurring.

## Git Workflow (STRICT)

### Atomic Commits

- **One logical change per commit** — never bundle unrelated changes together
- **Commit as you go** — after each file or small group of related files, not in bulk at the end
- Examples of proper atomic commits:
  - `feat: add vitest config and test setup` (infra only)
  - `test: add uiStore tests` (one store)
  - `test: add TaskCard component tests` (one component)
  - `ci: add GitHub Actions workflow` (CI only)
- **Never** make large catch-all commits like "add test suite (152 tests)" or "fix everything"

### Gitflow

- **main** — production-ready, protected. **NEVER create PRs directly to main.**
- **develop** — integration branch. All feature/fix PRs target `develop`, not `main`.
- **feat/<name>** — feature branches for new functionality
- **fix/<name>** — bugfix branches
- **chore/<name>** — maintenance, refactoring, tooling
- **test/<name>** — test-only additions
- Always branch from `develop`, always PR back to `develop`
- Branch names should be descriptive: `feat/pomodoro-timer`, not `feat/stuff`

### Worktrees

- Use `.worktrees/<branch-name>` for isolated feature work — already gitignored at `.gitignore:48`. The Claude Code harness uses a separate `.claude/worktrees/` for its own session worktrees; don't conflate the two
- Each worktree needs its own `.env` (gitignored, not shared via the worktree mechanism) — copy `.env` from the main repo
- **`gh pr merge --merge`, not `--squash`** when a branch has a coherent atomic-commit history — squash collapses the granular commits into one opaque blob, breaking `git blame` and per-commit revertability. `--squash` is only appropriate for noisy WIP branches
- **Worktree corruption recovery**: If `git worktree add` is killed mid-checkout (interrupt, TaskStop, etc.), the worktree's index ends up out of sync — every file shows as both `D` (deleted from index) and `??` (untracked). Don't try to repair in place; `git worktree remove --force <path>` and recreate
- **Dry-run merge for stale branches**: `git merge-tree --write-tree <base> <branch>` runs a true three-way merge to a tree object without touching the working tree or any branch. If output contains only `Auto-merging` lines (no `CONFLICT`), the merge is clean. Useful for triaging whether to rebase or merge an old branch before committing to either

### Commit Message Convention

```
<type>: <short description>

Types: feat, fix, test, chore, docs, refactor, ci, style
```

- Keep subject line under 72 characters
- Use imperative mood ("add", "fix", "update" — not "added", "fixes", "updated")
- Body is optional but encouraged for non-trivial changes

## GitHub Issues & Project Management

**Roadmap source of truth**: `docs/IDEA.md` is the master vision and feature spec. GitHub Issues represent the implementation plan — one issue per concrete deliverable, organized by phase (see IDEA.md §20).

**Project board**: All issues auto-flow into [project Omakase #11](https://github.com/users/WilsonSousajr/projects/11). Two built-in workflows do the routing:
- *Auto-add to project* (#7) — adds every new repo issue
- *Item added to project* (#6) — sets Status field to **Backlog** on add

These built-in workflows are **read-only via the GraphQL API** (`updateProjectV2Workflow` mutation does not exist). Configure them in the project's web UI only. Project IDs for scripted item edits:
- Project: `PVT_kwHOBTZlyM4BWF0D`
- Status field: `PVTSSF_lAHOBTZlyM4BWF0DzhRc0uI`
- Backlog option: `a28a01a9`

**Required label suite** — every new issue MUST be tagged across these categories:

| Category | Cardinality | Labels |
|---|---|---|
| **Phase** | 1 (when applicable) | `phase-1` … `phase-6` |
| **Domain** | 1+ | `backend`, `frontend`, `infra`, `database`, `mobile`, `desktop`, `design`, `integration` |
| **Type** | 1+ | `enhancement` (default), `bug`, `documentation`, `refactor`, `tech-debt`, `testing`, `performance`, `security`, `accessibility`, `i18n` |
| **Priority** | exactly 1 | `priority-critical`, `priority-high`, `priority-medium`, `priority-low` |
| **Effort** | exactly 1 | `effort-xs` (<2h), `effort-s` (½ day), `effort-m` (1-2d), `effort-l` (~1 week), `effort-xl` (multi-week) |
| **Status** | optional | `blocked`, `needs-design`, `needs-spec` |

**Issue body structure** — every new issue must include each of the following sections. When a section truly doesn't apply, write `N/A — [reason]` rather than omitting silently:

- **Background / Context** — why this exists, link to IDEA.md section
- **User stories** — "As a [role], I want [X] so that [Y]"
- **Scope (in)** — bullet list of inclusions
- **Out of scope** — explicit exclusions
- **Technical approach** — architecture, file paths, models, components
- **Data model** — exact field types, constraints, indexes, migration notes
- **API design** — endpoints, methods, request/response shapes with example JSON
- **UI/UX notes** — layouts, interactions, edge cases, empty/error states
- **Edge cases** — boundary conditions, concurrency, timezone gotchas
- **Acceptance criteria** — testable checklist
- **Testing strategy** — backend (pytest, factories) + frontend (vitest, MSW)
- **Dependencies** — blocked-by / blocks references to other issues
- **References** — IDEA.md sections, design-system.md, similar code
- **Risks / Migration notes** — data migrations, breaking changes, rollback plan
- **Open questions** — anything still to decide

**Bulk issue creation**: confirm structure (per-feature vs. mega-issue vs. epic-with-children) before running `gh issue create` in a loop — bulk issue creation affects shared repo state and is hard to undo. After creating many issues, verify with `gh issue list --label <phase>`.

**Useful gh patterns**:
- Create issue with body via heredoc: `gh issue create --title "..." --label "..." --body "$(cat <<'EOF' ... EOF)"` — single-quoted heredoc prevents shell expansion of backticks and `$` inside markdown bodies
- Bulk add labels: `gh issue edit <num> --add-label "label1,label2,label3"`
- Bulk set project status: `gh project item-edit --id <item> --project-id <pid> --field-id <fid> --single-select-option-id <opt>`
- Inspect project workflows: GraphQL `projectV2.workflows(first: 20) { nodes { id name enabled number } }` (read-only)

## Testing Gotchas

- **Backend UUID comparison**: DRF responses return UUID objects, not strings — use `str()` when comparing: `str(resp.data["task"]) == str(task.pk)`
- **Backend hex validation**: `TagFactory(color="notacolor")` hits DB varchar(7) limit before Django validation — use `TagFactory.build()` + `full_clean()` for validator tests
- **Backend TimeBlock constraint**: `end_time <= start_time` is now caught by serializer `validate()` (returns 400). DB constraint still exists as a safety net — test the serializer path with `resp.status_code == 400`
- **factory-boy deprecation**: `TaskFactory._after_postgeneration` save warning — add `skip_postgeneration_save=True` in Meta to suppress
- **UserFactory password**: Use `@post_generation` hook with manual `save()` — `PostGenerationMethodCall("set_password")` + `skip_postgeneration_save=True` would skip saving the hashed password
- **Backend auth tests**: Use `authenticated_client` fixture (JWT Bearer token) — `api_client` fixture returns 401 on all user-scoped endpoints
- **Timezone mismatch (Docker UTC)**: Backend runs in Docker (UTC). Never rely on server-side `date.today()` for user-facing "today" logic — always send the client's local date as a query param. The `/tasks/today/?date=` endpoint was added to fix tasks not showing in focus mode near midnight
- **Behavior-change commits MUST update their tests in the same commit**: When tightening an API contract (e.g. making a query param required, returning 400 instead of a silent fallback), update the corresponding tests in the same commit. Stale tests that assert the old behavior will sit on a long-lived branch undetected and only break CI after a rebase/merge — and the fix becomes a separate "test catch-up" commit that loses the connection to the behavior change. This is the same hygiene as bug-fix tests, applied to behavior changes

## Local Environment Notes

- Use `docker-compose` (hyphenated), not `docker compose` (space-separated)
- Backend dev deps installed at runtime (volume mount), not baked into image — run `docker-compose exec backend pip install -r requirements-dev.txt` after container rebuild
- **Running an isolated worktree's stack alongside other Compose projects**: postgres :5432 and backend :8000 may already be bound on the host. Create a gitignored `docker-compose.override.yml` in the worktree to remap host ports, and pass `-p <unique-name>` to `docker-compose` so volumes/networks don't collide with the main repo's stack
- **Compose list-merge semantics — `!override` vs `!reset`**: Compose's default merge strategy *unions* list values, so a base `ports: ["5432:5432"]` plus an override `ports: ["5433:5432"]` gives you BOTH bindings (and one fails). Use `ports: !override` to replace the list, or `ports: !reset` to clear without replacing — they are not the same and silently doing the wrong one wastes time

## Code Style

### Functions & files

- Functions: 4-20 lines. Split if longer.
- Files: under 500 lines. Split by responsibility.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`. Prefer names that return <5 grep hits in the codebase.
- Types: explicit. No `any`, no `Dict`, no untyped functions.
- No code duplication. Extract shared logic into a function/module.
- Early returns over nested ifs. Max 2 levels of indentation.
- Exception messages must include the offending value and expected shape.

### Comments

- Keep your own comments. Don't strip them on refactor — they carry intent and provenance.
- Write WHY, not WHAT. Skip `// increment counter` above `i++`.
- Docstrings on public functions: intent + one usage example.
- Reference issue numbers / commit SHAs when a line exists because of a specific bug or upstream constraint.

### Tests

- Tests run with a single command: `docker-compose exec backend pytest`.
- Every new function gets a test. Bug fixes get a regression test.
- Mock external I/O (API, DB, filesystem) with named fake classes, not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable, self-validating, timely.

### Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

### Structure

- Follow the framework's convention (Django apps).
- Prefer small focused modules over god files.
- Predictable paths: `views/serializers/models` (Django).

### Layered architecture

- Views must have almost 0 business logic — all business logic lives inside services.
- Models must handle only data-related things, entities, etc. (fields, simple `clean()` / `save()` overrides, query helpers — not multi-step orchestration).
- Backend (Django): keep `views.py` thin (parse → call service → return). Business logic goes in `<app>/services.py` modules; serializers stay focused on shape/validation, not workflow.

### Formatting

- Use the language default formatter (`ruff format` for Python). Don't discuss style beyond that.

### Logging

- Structured JSON when logging for debugging / observability.
- Plain text only for user-facing CLI output.

## Workflow Rules

- **Always update CLAUDE.md** after completing an implementation or discovering new patterns, gotchas, or learnings
- **Always update `/docs`** — maintain `docs/` as the self-reference documentation for all modules, features, architecture decisions, and implementation details. When you need to understand how something works, look here first. Update after every significant change.
- **Delete plan files after completing a plan** — once a plan is fully implemented, remove the plan file from `docs/plans/`
- **Always clean up worktrees** — after finishing work on a branch (merged, abandoned, or PR created), immediately remove the worktree with `git worktree remove` or `rm -rf` + `git worktree prune`. Never leave stale worktrees around.
- **Always apply the full label suite to new GitHub issues** — phase + domain + priority + effort + type, plus the detailed body structure (Background, Scope, Technical approach, Data model, API design, UI/UX, Edge cases, Acceptance criteria, Testing strategy, Dependencies, References, Risks, Open questions). See "GitHub Issues & Project Management" section above.

When I report a bug, don't start by trying to fix it. Instead, start by writing a test that reproduces the bug. Then, have subagents try to fix the bug and prove it with a passing test.

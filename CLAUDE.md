# Omakase

Productivity app (Notion + Sunsama + Focusbrew). Currently Work module only.

## Architecture

- **Frontend**: Next.js 15 (App Router) + TypeScript + Tailwind CSS 4 + TanStack Query + Zustand
- **Backend**: Django 5.2 + Django REST Framework 3.16 + PostgreSQL 16
- **Infrastructure**: Docker Compose (3 services: db, backend, frontend)

## Quick Start

```bash
docker compose up          # Start all services
docker compose up -d       # Start detached
docker compose down        # Stop all services
docker compose logs -f     # Follow logs
```

Services: frontend :3000 | backend :8000 | postgres :5432

## Backend Commands

```bash
docker compose exec backend python manage.py makemigrations
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py shell
```

## Frontend Commands

```bash
docker compose exec frontend pnpm install    # Install deps (after adding new packages)
docker compose exec frontend pnpm lint       # Run linter
# For adding packages, run pnpm add locally then `pnpm install` inside container
```

## Project Structure

```
backend/
  omakase/         # Django project settings, urls, wsgi
  tasks/           # Task, Tag, TimeBlock models + API
  pomodoro/        # PomodoroSession model + API
frontend/
  src/
    app/           # Next.js App Router pages (/plan, /focus)
    components/    # React components (tasks/, calendar/, kanban/, focus/)
    hooks/         # TanStack Query hooks (useTasks, useTags, useTimeBlocks, usePomodoro)
    stores/        # Zustand stores (uiStore, pomodoroStore, calendarStore)
    lib/           # Utilities (api, constants, utils)
    types/         # TypeScript types
```

## API Endpoints (all under /api/v1/)

- `tasks/` — CRUD + `today/` + `reorder-bulk/`
- `tags/` — CRUD, filterable by area
- `timeblocks/` — CRUD, filterable by date range
- `pomodoro/sessions/` — Create, list, patch (complete)

## Design System

- **Monochrome palette** — wstech.tech-inspired, dark-only. See `docs/design-system.md` for full spec.
- **Font:** Outfit (geometric sans-serif) via Next.js Google Fonts
- **Signature:** Section labels use `text-[10px] font-semibold uppercase tracking-[0.15em]` (kanban headers, form labels, time labels)
- **Colors:** CSS custom properties in `globals.css` `:root` — use `var(--color-*)` not hardcoded zinc/indigo
- **Accents:** Functional only — priority colors (gray/amber/orange/red) for badges and time blocks. Everything else is grayscale.
- **Border radius:** `rounded-2xl` cards, `rounded-xl` inputs/buttons, `rounded-lg` badges
- **Active states:** White/gray (no indigo) — `var(--color-surface-active)` for nav, `white/20` ring for cards

## Security & Configuration

- `.env` file is **required** — `docker compose up` will fail without it. Copy `.env.example` and fill in real values.
- `SECRET_KEY` and `DATABASE_URL` raise `ImproperlyConfigured` if missing (no insecure fallbacks)
- `DEBUG` defaults to `False` (must explicitly set `DJANGO_DEBUG=True` in `.env` for development)
- DRF uses `AllowAny` permission by default (switch to `IsAuthenticated` when auth is implemented); `SessionAuthentication` is pre-configured
- CORS only allows explicit origins (no `CORS_ALLOW_ALL_ORIGINS`)
- PostgreSQL port bound to `127.0.0.1` only (not exposed to network)
- `reorder-bulk` endpoint capped at 100 items per request; uses `transaction.atomic()` + `select_for_update()` for race condition safety
- Next.js security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`
- Pre-commit hooks configured (`.pre-commit-config.yaml`): ruff lint/format, detect-secrets, trailing-whitespace, no-commit-to-branch

## Key Patterns

- UUIDs as primary keys on all models
- TanStack Query for server state, Zustand for UI state
- `TaskListSerializer` (lightweight) for list views, `TaskSerializer` (full with time_blocks) for detail
- Tags: accept `tag_ids` on write, return nested `tags` on read
- Optimistic updates on kanban drag via local state + reorder-bulk API (with rollback on error)
- Debounced auto-save on markdown notes (`NOTES_DEBOUNCE_MS` in constants)
- `completed_at` is read-only — set server-side when `is_completed` changes
- Shared constants in `backend/tasks/constants.py` and `frontend/src/lib/constants.ts` — avoid magic numbers
- `ErrorBoundary` wraps `{children}` in root layout to catch render errors
- `AudioContext` reused via `useRef` in PomodoroTimer (not recreated per notification)
- Markdown preview uses `rehype-sanitize` to prevent XSS
- Tag model `color` field validated with hex color regex
- Zustand selectors: use `useStore((s) => s.field)` not destructuring — prevents over-subscription and unnecessary re-renders
- `TaskCard` wrapped in `React.memo` — prevents re-render of every card when any sibling changes
- `taskMap` in calendar views memoized with `useMemo` — prevents object recreation on every render
- `TimeBlockSerializer.validate()` rejects `end_time <= start_time` at serializer level (400, not DB IntegrityError)

## Drag & Drop (Plan Mode)

- Uses `@dnd-kit/core` with `PointerSensor` (`DRAG_ACTIVATION_DISTANCE` in constants)
- Entire task card is the drag surface (listeners on wrapper div, not just grip icon)
- Edit/delete buttons use `onPointerDown` stopPropagation to avoid triggering drags
- Dropping a task on a calendar slot creates a TimeBlock AND sets `scheduled_date` — chained with `mutateAsync` + try/catch (not fire-and-forget)
- Existing time blocks can be repositioned by dragging within the calendar

## Calendar Time Blocks

- Time blocks are colored by task priority (gray/amber/orange/red), not a fixed color
- Priority badge shown inline next to task title
- Bottom resize handle (visible on hover) allows dragging to change `end_time` — snaps to 15-min increments, min 15 min, max 22:00
- Resize uses native mouse events (mousedown/mousemove/mouseup), not dnd-kit; height driven by React state (not DOM manipulation)

## Plan ↔ Focus Mode Sync

- Creating a time block in plan mode auto-sets `scheduled_date` so the task appears in focus mode's kanban (`/tasks/today/` filters by `scheduled_date`)
- All time block mutations (create/update/delete) invalidate both `["timeblocks"]` and `["tasks"]` query caches

## Keyboard Shortcuts

- `N` — New task
- `Escape` — Close modal
- `Space` — Toggle pomodoro timer (when not in input)

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
**Factories:** `backend/conftest.py` — TagFactory, TaskFactory, TimeBlockFactory, PomodoroSessionFactory
**Test files:** `backend/{tasks,pomodoro}/tests/test_{models,serializers,views}.py`

### Frontend (Vitest + React Testing Library + MSW)

```bash
cd frontend
pnpm test            # single run
pnpm test:watch      # watch mode
pnpm test:coverage   # with coverage report
```

**Config:** `frontend/vitest.config.ts`
**Setup:** `frontend/src/test/setup.ts` — jest-dom, cleanup, next/navigation mock
**Utilities:** `frontend/src/test/utils.tsx` — `renderWithProviders()` with test QueryClient
**MSW Handlers:** `frontend/src/test/handlers.ts` — mock API endpoints + data factories
**Test files:** `frontend/src/{stores,hooks,components}/**/__tests__/*.test.{ts,tsx}`

### CI Pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on push to main and PRs:
- **Frontend job:** pnpm install → lint → `tsc --noEmit` → test → build
- **Backend job:** PostgreSQL service → pip install → `ruff check` + `ruff format --check` → migrate → pytest with `--cov-fail-under=60`

### Test Patterns

- Backend: `@pytest.mark.django_db` on all DB-touching tests, factory-boy for test data
- Frontend stores: Direct `getState()`/`setState()` — no rendering needed
- Frontend hooks: `renderHook()` + MSW for API mocking
- Frontend components: `renderWithProviders()` wrapper includes QueryClientProvider
- Mock `@dnd-kit/*` in component tests that use drag-and-drop

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

- **main** — production-ready, only receives merges from feature/release branches
- **feat/<name>** — feature branches for new functionality
- **fix/<name>** — bugfix branches
- **chore/<name>** — maintenance, refactoring, tooling
- **test/<name>** — test-only additions
- Always branch from `main`, always PR back to `main`
- Branch names should be descriptive: `feat/pomodoro-timer`, not `feat/stuff`

### Commit Message Convention

```
<type>: <short description>

Types: feat, fix, test, chore, docs, refactor, ci, style
```

- Keep subject line under 72 characters
- Use imperative mood ("add", "fix", "update" — not "added", "fixes", "updated")
- Body is optional but encouraged for non-trivial changes

## Testing Gotchas

- **Backend UUID comparison**: DRF responses return UUID objects, not strings — use `str()` when comparing: `str(resp.data["task"]) == str(task.pk)`
- **Backend hex validation**: `TagFactory(color="notacolor")` hits DB varchar(7) limit before Django validation — use `TagFactory.build()` + `full_clean()` for validator tests
- **Backend TimeBlock constraint**: `end_time <= start_time` is now caught by serializer `validate()` (returns 400). DB constraint still exists as a safety net — test the serializer path with `resp.status_code == 400`
- **Frontend hook tests**: Files using JSX wrapper functions must be `.tsx`, not `.ts`
- **Frontend dnd-kit mocks**: Must include `useDroppable` in `@dnd-kit/core` mock for KanbanColumn
- **Frontend "Focus" text**: Appears in both tab and timer label — use `getAllByText` not `getByText`
- **factory-boy deprecation**: `TaskFactory._after_postgeneration` save warning — add `skip_postgeneration_save=True` in Meta to suppress

## Local Environment Notes

- Use `docker-compose` (hyphenated), not `docker compose` (space-separated)
- `pnpm` is not on PATH — use `npx pnpm` for local frontend commands
- Backend dev deps installed at runtime (volume mount), not baked into image — run `docker-compose exec backend pip install -r requirements-dev.txt` after container rebuild

## Workflow Rules

- **Always update CLAUDE.md** after completing an implementation or discovering new patterns, gotchas, or learnings
- **Always update `/docs`** — maintain `docs/` as the self-reference documentation for all modules, features, architecture decisions, and implementation details. When you need to understand how something works, look here first. Update after every significant change.
- **Delete plan files after completing a plan** — once a plan is fully implemented, remove the plan file from `docs/plans/`
- **Always update `docs/design-system.md`** when making any frontend UI/UX changes — keep it current with colors, spacing, typography, component patterns, and design decisions

# Omakase

Productivity app (Notion + Sunsama + Focusbrew). Work + Study modules.

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

### Pre-commit Setup

```bash
pip install pre-commit     # Install pre-commit binary
pre-commit install         # Install git hooks
```

Pre-commit runs automatically on `git commit`: ruff lint/format for Python, ESLint via lint-staged for TypeScript/TSX, detect-secrets, and standard file checks.

## Docker Builds

Both Dockerfiles use multi-stage builds with `dev` and `prod` targets:

```bash
# Dev (default — used by docker-compose up)
docker-compose up                    # targets dev stage, bind mounts for hot reload

# Production builds
docker build --target prod -t omakase-frontend:prod ./frontend
docker build --target prod -t omakase-backend:prod ./backend

# Production via compose override
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

- **Frontend prod** uses Next.js standalone output (~200-250MB vs ~1.8GB dev). Non-root `nextjs` user (UID 1001)
- **Backend prod** runs as non-root `django` user (UID 1001). Includes `collectstatic`
- **`NEXT_PUBLIC_API_URL`** must be passed as build arg for prod (baked at build time by Next.js)
- **`.dockerignore`** files exclude build artifacts, IDE files, and (frontend only) test files from build context. Backend keeps test files in context because the dev stage needs them at build time.
- CI enforces frontend prod image < 500MB via `docker-build` job

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
  accounts/        # Auth: Google OAuth login, me endpoint, Profile model, user preferences
  omakase/         # Django project settings, urls, wsgi
  tasks/           # Task, Tag, TimeBlock, Workspace, Project models + API
  pomodoro/        # PomodoroSession model + API
  study/           # Semester, Discipline, StudyBlock, ClassSchedule models + API
  stats/           # Daily stats aggregation + DailyReview model + ReviewSummaryView
frontend/
  src/
    app/(auth)/    # Login page with Google Sign-In (no sidebar)
    app/(main)/    # Plan + Focus + Review + Projects + Study + Settings pages (with sidebar)
    components/    # React components (tasks/, calendar/, kanban/, focus/, projects/, study/, review/)
    hooks/         # TanStack Query hooks (useTasks, useTags, useTimeBlocks, usePomodoro, useAuth [useMe, useGoogleAuth, useUpdateProfile, useLogout], useWorkspaces, useProjects, useStats, useSemesters, useDisciplines, useStudyBlocks, useClassSchedules, useClassOccurrences, useDailyReviews, useUserProfile)
    stores/        # Zustand stores (uiStore, pomodoroStore, calendarStore, authStore)
    lib/           # Utilities (api with JWT interceptors, constants, utils)
    types/         # TypeScript types (task, tag, timeblock, pomodoro, auth [User, AuthTokens, GoogleAuthResponse, UpdateProfilePayload], stats, semester, discipline, studyblock, classschedule, dailyreview, userprofile)
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

## Design System

- **Monochrome palette** — wstech.tech-inspired, light + dark themes. See `docs/design-system.md` for full spec.
- **Theme:** `next-themes` with `attribute="class"`, `defaultTheme="system"`, `storageKey="omakase-theme"`. ThemeToggle in sidebar footer cycles system → light → dark.
- **CSS variables:** Light values in `:root`, dark values in `.dark` class. Never use hardcoded `bg-white/*` or `text-white` — use overlay variables (`--color-hover-overlay`, `--color-overlay-medium`, `--color-ring-overlay`).
- **Font:** Outfit (geometric sans-serif) via Next.js Google Fonts
- **Signature:** Section labels use `text-[10px] font-semibold uppercase tracking-[0.15em]` (kanban headers, form labels, time labels)
- **Colors:** CSS custom properties in `globals.css` — use `var(--color-*)` not hardcoded zinc/indigo
- **Accents:** Functional only — priority colors (gray/amber/orange/red) for badges and time blocks. Everything else is grayscale.
- **Border radius:** `rounded-2xl` cards, `rounded-xl` inputs/buttons, `rounded-lg` badges
- **Active states:** Gray (no indigo) — `var(--color-surface-active)` for nav, `var(--color-ring-overlay)` ring for cards

## Security & Configuration

- `.env` file is **required** — `docker compose up` will fail without it. Copy `.env.example` and fill in real values.
- `SECRET_KEY` and `DATABASE_URL` raise `ImproperlyConfigured` if missing (no insecure fallbacks)
- `DEBUG` defaults to `False` (must explicitly set `DJANGO_DEBUG=True` in `.env` for development)
- DRF uses `IsAuthenticated` permission by default; `JWTAuthentication` + `SessionAuthentication` configured
- JWT: 60-min access tokens, 7-day refresh tokens (djangorestframework-simplejwt)
- Google OAuth: Frontend `@react-oauth/google` sends ID token → Backend verifies via `google-auth` → Issues JWT pair
- `GOOGLE_CLIENT_ID` env var required for Google login (validated at runtime in GoogleLoginView)
- `NEXT_PUBLIC_GOOGLE_CLIENT_ID` env var for frontend GoogleOAuthProvider
- Auth endpoint (google/) uses explicit `AllowAny` override
- Frontend: JWT tokens stored in localStorage via authStore, auto-attached by axios interceptor
- Token refresh: 401 → auto-refresh with concurrent request queue (prevents multiple refresh calls)
- Route groups: `(auth)` for login (no sidebar), `(main)` for plan/focus (with sidebar)
- AuthGuard wraps root layout — redirects unauthenticated users to /login
- CORS only allows explicit origins (no `CORS_ALLOW_ALL_ORIGINS`)
- PostgreSQL port bound to `127.0.0.1` only (not exposed to network)
- `reorder-bulk` endpoint capped at 100 items per request; uses `transaction.atomic()` + `select_for_update()` for race condition safety
- Next.js security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`
- Pre-commit hooks configured (`.pre-commit-config.yaml`): ruff lint/format, detect-secrets, trailing-whitespace, no-commit-to-branch, frontend ESLint via lint-staged
- `rest_framework_simplejwt.token_blacklist` in INSTALLED_APPS — enables refresh token blacklisting
- No password auth — all authentication via Google OAuth (no register, login, or change-password endpoints)

## Key Patterns

- UUIDs as primary keys on all models (except User which uses Django's built-in int PK)
- All models have `user` FK (nullable during migration phase) — ViewSets enforce user scoping via `get_queryset()` + `perform_create()`
- When removing `queryset` from ViewSet, must add `basename` to `router.register()` — DRF can't auto-detect
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
- Workspace/Project hierarchy: Workspace → Project → Task (optional). Project scoped via `workspace.user`. Task has nullable `project` FK (SET_NULL on delete)
- Annotated querysets (Count) must add explicit `.order_by()` — annotations lose model-level ordering, causing DRF pagination warnings
- Workspace/Project serializers include computed `project_count`/`task_count` via annotation (not DB field)
- Frontend: `useProjects` create/delete mutations invalidate both `["projects"]` and `["workspaces"]` queries (project_count changes)
- Frontend: TaskCard receives optional `projects: Map<string, Project>` for O(1) project badge lookup (avoids n+1 queries)
- Frontend: ProjectBadge uses FolderOpen icon + colored badge (same pattern as tag badges)
- Frontend: Projects page groups projects by status (Active/Paused/Completed/Archived), uses modal for create/edit
- Frontend: Sidebar workspace selector sets `activeWorkspaceId` in uiStore — used to filter projects page
- Frontend: TaskForm project dropdown shows all user's projects (not filtered by workspace)
- Frontend: `PROJECT_STATUSES` in constants.ts with derived `ProjectStatus` type
- Stats app: DailyStatsView (read-only aggregation) + DailyReview model + ReviewSummaryView + DailyReviewViewSet
- Frontend: `useDailyStats()` hook auto-refetches every 60s via `refetchInterval`
- Frontend: SidebarStats renders at sidebar bottom (`mt-auto`), hidden when collapsed, sections hide when no data
- Study hierarchy: Semester → Discipline → StudyBlock (parallels Workspace → Project → Task)
- Discipline scoped via `semester.user`, StudyBlock via `discipline.semester.user` (same pattern as Project → workspace.user)
- StudyBlock.save() syncs `is_completed ↔ status` (mirrors Task pattern)
- TimeBlock polymorphic FK: nullable `task` + nullable `study_block`, CASCADE on delete, CheckConstraint requires at least one non-null
- TimeBlockSerializer validates exactly one of task/study_block on write
- TimeBlockViewSet uses Q(task__user) | Q(study_block__discipline__semester__user) with .distinct()
- `block_type` field name (not `type`) to avoid Python reserved word conflict
- Frontend: Study page shows semesters grid + disciplines grouped by status (mirrors Projects page)
- Frontend: Discipline detail page at `/study/[disciplineId]` lists study blocks with type/status filters
- Frontend: Sidebar has semester selector (parallels workspace selector) + BookOpen Study nav item
- Frontend: `activeSemesterId` in uiStore filters discipline list on study page
- Frontend: `useDisciplines` create/delete mutations invalidate both `["disciplines"]` and `["semesters"]` queries (discipline_count changes)
- Frontend: `useStudyBlocks` create/delete mutations invalidate both `["studyblocks"]` and `["disciplines"]` queries (study_block_count changes)
- Frontend: StudyBlockCard uses `React.memo` with discipline `Map<string, Discipline>` for O(1) lookup (same as TaskCard + projects)
- Frontend: StudyBlockForm uses `modalOpen === "studyblock-form"`, DisciplineForm uses `"discipline-form"`, SemesterForm uses `"semester-form"`
- Frontend: TimeBlockItem supports both task and study_block rendering — uses discipline color for study blocks, BookOpen icon
- Frontend: TodayStudyBlocks panel in focus page shows scheduled study blocks below kanban (read-only, not draggable)
- Frontend: Plan page drag handler supports `type: "studyblock"` — creates TimeBlock with `study_block` FK
- ClassSchedule: recurring weekly class blocks (discipline FK, day_of_week 0-6, start/end_time, class_type, location, is_active)
- ClassSchedule CheckConstraint: end_time > start_time, day_of_week 0-6
- ClassOccurrenceView computes virtual occurrences on-the-fly (not persisted) for a date range, respects semester boundaries
- Class occurrence composite IDs: `{schedule_id}-{date}` (since they're not DB rows)
- ClassOccurrenceView: max 90-day range, requires both date_from and date_to params
- Frontend: ClassBlockItem is read-only (dashed border, lighter bg, BookOpen icon, not draggable/resizable)
- Frontend: CalendarDayView renders class occurrences before time blocks (class blocks layer behind interactive blocks)
- Frontend: ClassScheduleForm uses `modalOpen === "classschedule-form"`, managed from discipline detail page
- Frontend: Discipline detail page has class schedule management section with add/edit/delete
- DailyReview in stats app — stores productivity_rating (1-5), win_of_the_day, is_shutdown + shutdown_at
- DailyReview unique_together (user, date) — serializer validates via request context since user not in serializer fields
- DailyReviewViewSet.perform_update auto-stamps shutdown_at when is_shutdown transitions to True
- ReviewSummaryView aggregates TimeBlock, Task, StudyBlock, PomodoroSession data for any given date
- Review page is a 6-step wizard: Summary → Rollover → Score → Win → Preview → Shutdown
- Rollover = PATCH scheduled_date on tasks/study blocks (tomorrow, pick date, or null for backlog)
- Study block "skip" action sets status="skipped" (not just clearing scheduled_date)
- Shutdown nudge: toast on plan/focus pages when today's review has is_shutdown=true, shown once per session via uiStore flag
- Frontend: useReviewSummary(date) hook for the aggregation endpoint, useDailyReview(date) for CRUD
- Frontend: emitToast exported from Toast.tsx for programmatic toast messages
- Frontend: Review wizard state (step, rating, win, reviewId) owned by page, each step is a pure component with props
- Frontend: `editTask` state lives in uiStore (not local component state) — allows TaskForm to work from any page
- Frontend: TaskForm is mounted globally in `app/(main)/layout.tsx` — reads `editTask` and `modalOpen` from uiStore
- Frontend: KanbanCard (focus page) — entire card is drag surface (listeners on wrapper div), same pattern as plan page TaskCard
- Frontend: Review page has Today/History tab bar (same pattern as MarkdownEditor tabs), tab state in useState (not URL)
- Frontend: `useDailyReviewsList(page)` hook for paginated history, query key `["daily-reviews", "list", page]` (auto-invalidated by existing mutations)
- Frontend: ReviewHistoryCard uses `React.memo`, lazy-loads summary via `useReviewSummary(date)` with `enabled: expanded`
- Frontend: ReviewHistory accumulates pages via `useEffect` (page 1 replaces, subsequent pages append) — no `useInfiniteQuery`
- Profile model: OneToOneField to User, auto-created via `post_save` signal in `accounts/signals.py`
- Profile: `avatar_color` (hex, default `#a3a3a3`), `created_at`, `updated_at`
- MeView: `RetrieveUpdateAPIView` — GET returns `UserSerializer`, PATCH uses `UpdateProfileSerializer` (writes to both User and Profile)
- UpdateProfileSerializer: plain Serializer (not ModelSerializer) because it writes to two models (User + Profile), wrapped in transaction.atomic()
- GoogleLoginView: POST `/auth/google/`, verifies Google ID token via `google-auth`, gets-or-creates user by email, backfills name from Google profile, issues JWT pair. Username auto-generated from email prefix (handles collisions)
- Frontend: Login page uses `GoogleLogin` component from `@react-oauth/google`, no register page
- Frontend: Settings page email field is read-only (managed by Google), no password change section
- Frontend: UserAvatar component with `getInitials()` helper — falls back: first+last → first[0:2] → username[0:2]
- Frontend: Sidebar user section (above SidebarStats) — UserAvatar + username + Settings gear icon, links to `/settings`
- Frontend: `useUpdateProfile()` PATCH `/auth/me/` → updates authStore + query cache
- Frontend: `useGoogleAuth()` POST `/auth/google/` → receives JWT + user in single response, stores via authStore.setAuth()
- UserProfile: OneToOne with User (related_name="user_profile"), auto-created via post_save signal. View uses get_or_create for existing users
- UserProfile stores pomodoro durations, daily goals (work/study hours), timezone, week_starts_on
- Frontend: Settings page at `/settings` combines profile editing (name, email, avatar color), preferences (pomodoro, daily goals, general), password change, and logout
- Frontend: PomodoroTimer fetches user profile and syncs durations into pomodoroStore via useEffect + setDurations
- Frontend: pomodoroStore has `durations` and `pomodorosBeforeLongBreak` as mutable state (not module-level constants)
- Frontend: `setDurations` only updates `timeRemaining` when timer is not running (prevents resetting mid-session)

## i18n (Internationalization)

- **Library:** `next-intl` in client-only mode (no middleware, no URL routing)
- **Locales:** English (`en`) + Portuguese BR (`pt-BR`), default `en`
- **Messages:** `frontend/messages/en.json` and `frontend/messages/pt-BR.json` — organized by domain namespace
- **Locale store:** `localeStore` (Zustand + localStorage, key `omakase-locale`) — same pattern as authStore
- **Provider:** `NextIntlClientProvider` in `Providers.tsx`, reads locale from `localeStore` with `hasMounted` gate
- **Config:** `frontend/src/i18n/config.ts` (locales, defaultLocale), `frontend/src/i18n/getMessages.ts` (message loader)
- **LocaleSwitcher:** Sidebar footer toggle (EN / PT-BR), compact icon buttons
- **Constants strategy:** `constants.ts` unchanged — at render sites use `tc(\`priorities.${value}\`)` not `priority.label`
- **Common translations:** `const tco = useTranslations("common")` for shared buttons (cancel, save, loading...)
- **Date formatting:** Use `useFormatter().dateTime(date, options)` for locale-aware display dates. Keep `date-fns` `format()` for API date strings (`yyyy-MM-dd`).
- **Test mock:** `setup.ts` mocks `next-intl` with real English messages for assertions against actual text
- **Adding new strings:** Add key to both `en.json` and `pt-BR.json`, use `t("key")` in component

## Drag & Drop (Plan Mode)

- Uses `@dnd-kit/core` with `PointerSensor` (`DRAG_ACTIVATION_DISTANCE` in constants)
- Entire task card is the drag surface (listeners on wrapper div, not just grip icon)
- Edit/delete buttons use `onPointerDown` stopPropagation to avoid triggering drags
- Dropping a task on a calendar slot creates a TimeBlock AND sets `scheduled_date` — chained with `mutateAsync` + try/catch (not fire-and-forget)
- Existing time blocks can be repositioned by dragging within the calendar
- Repositioning a time block to a different day also syncs the parent task/study block's `scheduled_date`

## Calendar Time Blocks

- **Notion-style accent stripe design:** Left colored stripe (`w-1`) carries priority/discipline color, white title text for readability
- Priority badge shown inline next to task title
- Bottom resize handle (visible on hover) allows dragging to change `end_time` — snaps to 15-min increments, min 15 min, max 22:00
- Resize uses native mouse events (mousedown/mousemove/mouseup), not dnd-kit; height driven by React state (not DOM manipulation)
- `data-timeblock` / `data-classblock` attributes on blocks prevent click-to-create from triggering on them
- **Shared utilities:** `calendarUtils.ts` exports `timeToOffset`, `timeToMinutes`, `minutesToTime`, `HOURS`, `SLOT_HEIGHT_DAY`, `SLOT_HEIGHT_WEEK`
- **Shared TimeSlot component:** Unified droppable slot used by both DayView and WeekView
- **CurrentTimeIndicator:** Red line + dot at current time, updates every 60s, only renders for today
- **Grid line hierarchy:** Hour lines `/60` opacity, half-hour lines `/20` opacity (Notion Calendar style)
- **Click-to-create (day view only):** `useClickToCreate` hook with 5px dead zone, 15-min snap. Drawing creates `CreationOverlay`, mouseup opens TaskForm. `calendarStore.creationDraft` carries date/startTime/endTime. TaskForm creates TimeBlock after task creation if draft exists.
- **WeekView class occurrences:** Renders ClassBlockItem per column (was missing before)
- **WeekView day headers:** Two-line layout (day name + date number), today circle highlight, today column `bg-white/[0.02]`
- **CalendarHeader:** Pill-style Today button, larger date label, segmented view toggle

## Plan ↔ Focus Mode Sync

- Creating a time block in plan mode auto-sets `scheduled_date` so the task appears in focus mode's kanban (`/tasks/today/` filters by `scheduled_date`)
- Moving a time block to a different day syncs the parent task/study block's `scheduled_date` to match
- All time block mutations (create/update/delete) invalidate both `["timeblocks"]` and `["tasks"]` query caches
- Deleting a task or study block must also invalidate `["timeblocks"]` — DB CASCADE deletes the time blocks, but stale frontend cache causes ghost blocks on the calendar
- `/tasks/today/` accepts optional `?date=` query param — frontend sends client-local date to avoid server UTC mismatch
- `useTodayTasks(date)` requires a date string (from `useToday()` hook) — no longer uses server `date.today()` as default
- `useToday()` hook in `frontend/src/hooks/useToday.ts` returns local date as YYYY-MM-DD string
- TimeBlock model has `notes` (TextField, blank, default "") and `session_rating` (PositiveSmallIntegerField, null, 1-5 validated)
- `actual_minutes` computed via SerializerMethodField + `prefetch_related("time_blocks")` — avoids N+1, sums (end_time - start_time) in Python
- `/tasks/carried-over/?date=` returns incomplete tasks scheduled before the given date (used by Morning Plan wizard)
- `/study/studyblocks/carried-over/?date=` same pattern, excludes completed/skipped study blocks
- Frontend: `useCarriedOverTasks(date)` and `useCarriedOverStudyBlocks(date)` hooks for Morning Plan wizard
- Frontend: MorningPlanWizard is a 3-step modal wizard (Carried Over → Today's Schedule → Workload Summary), mounted in plan page
- Frontend: SessionCompletionModal triggered on drag-to-done (KanbanBoard) and pomodoro completion (PomodoroTimer) — rates time block 1-5 + optional notes
- Frontend: `sessionCompletionBlock` in uiStore for cross-component session completion coordination, `ratedBlockIds` ref in focus page prevents re-triggering
- Frontend: `findOverlaps()` in `timeblock-utils.ts` — pure function detecting time block + class occurrence overlaps, used in plan page handleDragEnd and handleCreateRange
- Frontend: OverlapWarning dialog with pendingAction pattern — stores mutation as state, executes on confirm, clears on cancel
- Frontend: ActiveTaskPanel shows session notes textarea for the current time block (debounced save, `useUpdateTimeBlock`)

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
**Factories:** `backend/conftest.py` — TagFactory, TaskFactory, TimeBlockFactory, PomodoroSessionFactory, SemesterFactory, DisciplineFactory, StudyBlockFactory
**Test files:** `backend/{accounts,tasks,pomodoro,study,stats}/tests/test_{models,serializers,views}.py`

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
- **Frontend job:** pnpm install → lint → `tsc --noEmit` → test (with `--coverage --coverage.thresholds.lines=50`) → build
- **Backend job:** PostgreSQL service → pip install → `ruff check` + `ruff format --check` → migrate → pytest with `--cov-fail-under=60`
- **Docker lint job:** hadolint on both Dockerfiles (catches anti-patterns)
- **Docker build job:** builds both prod images, verifies frontend image < 500MB (prevents size regression)
- **Concurrency:** `ci-${{ github.ref }}` group with `cancel-in-progress: true` — prevents wasted CI minutes on rapid pushes

### Test Patterns

- Backend: `@pytest.mark.django_db` on all DB-touching tests, factory-boy for test data
- Frontend stores: Direct `getState()`/`setState()` — no rendering needed
- Frontend hooks: `renderHook()` + MSW for API mocking
- Frontend components: `renderWithProviders()` wrapper includes QueryClientProvider
- Mock `@dnd-kit/*` in component tests that use drag-and-drop
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
- **Frontend next/link mock**: Must forward all props (especially `className`) via rest spread — `({ children, href, ...props }) => <a href={href} {...props}>{children}</a>` — otherwise `toHaveClass()` assertions fail
- **factory-boy deprecation**: `TaskFactory._after_postgeneration` save warning — add `skip_postgeneration_save=True` in Meta to suppress
- **UserFactory password**: Use `@post_generation` hook with manual `save()` — `PostGenerationMethodCall("set_password")` + `skip_postgeneration_save=True` would skip saving the hashed password
- **Backend auth tests**: Use `authenticated_client` fixture (JWT Bearer token) — `api_client` fixture returns 401 on all user-scoped endpoints
- **Frontend authStore tests**: Must use `vi.stubGlobal("localStorage", ...)` because store `.ts` files don't run in jsdom environment
- **Frontend localStorage in authStore**: Wrap in try-catch — `loadTokens()` runs at module init time when localStorage may not be available
- **Frontend SSR hydration + localStorage**: Components that read localStorage-backed Zustand state (e.g. `isAuthenticated`) must use a `hasMounted` gate (`useState(false)` + `useEffect` → `true`) to avoid hydration mismatch — server sees `null`, client sees stored value
- **Timezone mismatch (Docker UTC)**: Backend runs in Docker (UTC). Never rely on server-side `date.today()` for user-facing "today" logic — always send the client's local date as a query param. The `/tasks/today/?date=` endpoint was added to fix tasks not showing in focus mode near midnight
- **Vitest parallel JSON-import race**: Running the full frontend suite (~70+ files) can intermittently fail with `SyntaxError: messages/en.json: Unexpected end of JSON input` when multiple workers `require()` the shared `messages/en.json` simultaneously from `setup.ts`. The same files pass when run individually. Rerun with `npx vitest run --pool=forks` to serialize the import and get a clean signal — don't assume the JSON is corrupted
- **Behavior-change commits MUST update their tests in the same commit**: When tightening an API contract (e.g. making a query param required, returning 400 instead of a silent fallback), update the corresponding tests in the same commit. Stale tests that assert the old behavior will sit on a long-lived branch undetected and only break CI after a rebase/merge — and the fix becomes a separate "test catch-up" commit that loses the connection to the behavior change. This is the same hygiene as bug-fix tests, applied to behavior changes

## Local Environment Notes

- Use `docker-compose` (hyphenated), not `docker compose` (space-separated)
- `pnpm` is not on PATH — use `npx pnpm` for local frontend commands
- Backend dev deps installed at runtime (volume mount), not baked into image — run `docker-compose exec backend pip install -r requirements-dev.txt` after container rebuild
- **Running an isolated worktree's stack alongside other Compose projects**: postgres :5432, frontend :3000, and backend :8000 may already be bound on the host. Create a gitignored `docker-compose.override.yml` in the worktree to remap host ports, and pass `-p <unique-name>` to `docker-compose` so volumes/networks don't collide with the main repo's stack
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

- Tests run with a single command: `docker-compose exec backend pytest` (backend) or `npx pnpm test` from `frontend/` (frontend).
- Every new function gets a test. Bug fixes get a regression test.
- Mock external I/O (API, DB, filesystem) with named fake classes, not inline stubs.
- Tests must be F.I.R.S.T: fast, independent, repeatable, self-validating, timely.

### Dependencies

- Inject dependencies through constructor/parameter, not global/import.
- Wrap third-party libs behind a thin interface owned by this project.

### Structure

- Follow the framework's convention (Django apps, Next.js App Router, etc.).
- Prefer small focused modules over god files.
- Predictable paths: `views/serializers/models` (Django), `app/components/hooks/stores/lib/types` (Next.js).

### Formatting

- Use the language default formatter (`ruff format` for Python, `prettier`/Next ESLint for TS/TSX). Don't discuss style beyond that.

### Logging

- Structured JSON when logging for debugging / observability.
- Plain text only for user-facing CLI output.

## Workflow Rules

- **Always update CLAUDE.md** after completing an implementation or discovering new patterns, gotchas, or learnings
- **Always update `/docs`** — maintain `docs/` as the self-reference documentation for all modules, features, architecture decisions, and implementation details. When you need to understand how something works, look here first. Update after every significant change.
- **Delete plan files after completing a plan** — once a plan is fully implemented, remove the plan file from `docs/plans/`
- **Always update `docs/design-system.md`** when making any frontend UI/UX changes — keep it current with colors, spacing, typography, component patterns, and design decisions
- **Always clean up worktrees** — after finishing work on a branch (merged, abandoned, or PR created), immediately remove the worktree with `git worktree remove` or `rm -rf` + `git worktree prune`. Never leave stale worktrees around.

When I report a bug, don't start by trying to fix it. Instead, start by writing a test that reproduces the bug. Then, have subagents try to fix the bug and prove it with a passing test.

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

## Key Patterns

- UUIDs as primary keys on all models
- TanStack Query for server state, Zustand for UI state
- `TaskListSerializer` (lightweight) for list views, `TaskSerializer` (full with time_blocks) for detail
- Tags: accept `tag_ids` on write, return nested `tags` on read
- Optimistic updates on kanban drag via local state + reorder-bulk API
- Debounced auto-save on markdown notes (500ms)

## Drag & Drop (Plan Mode)

- Uses `@dnd-kit/core` with `PointerSensor` (5px activation distance)
- Entire task card is the drag surface (listeners on wrapper div, not just grip icon)
- Edit/delete buttons use `onPointerDown` stopPropagation to avoid triggering drags
- Dropping a task on a calendar slot creates a TimeBlock AND sets `scheduled_date` on the task (syncs with focus mode)
- Existing time blocks can be repositioned by dragging within the calendar

## Calendar Time Blocks

- Time blocks are colored by task priority (gray/amber/orange/red), not a fixed color
- Priority badge shown inline next to task title
- Bottom resize handle (visible on hover) allows dragging to change `end_time` — snaps to 15-min increments, min 15 min, max 22:00
- Resize uses native mouse events (mousedown/mousemove/mouseup), not dnd-kit

## Plan ↔ Focus Mode Sync

- Creating a time block in plan mode auto-sets `scheduled_date` so the task appears in focus mode's kanban (`/tasks/today/` filters by `scheduled_date`)
- All time block mutations (create/update/delete) invalidate both `["timeblocks"]` and `["tasks"]` query caches

## Keyboard Shortcuts

- `N` — New task
- `Escape` — Close modal
- `Space` — Toggle pomodoro timer (when not in input)

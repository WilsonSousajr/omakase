# M3.1 Data foundation: design

**Status:** approved section by section with the user, 2026-09-26 (#140).
**Milestone:** M3, "The daily loop" (`docs/ROADMAP.md`).
**Parent spec:** `docs/superpowers/specs/2026-09-25-macos-client-design.md`.

## M3, split

M3 is too large for one spec. The user agreed to six sub-projects, each with
its own spec, plan and PRs:

| # | Sub-project | Contents |
|---|---|---|
| M3.1 | Data foundation (this spec) | What every screen after it reads and writes through |
| M3.2 | Focus | List/Kanban on real data, the active-task panel with subtasks, complete, reschedule, the carried-over and plan-vs-due marks (#129) |
| M3.3 | Timer | A tested timer engine, a running session that survives a quit, the posted session, notes and rating on the block, the menu-bar timer, pomodoro notifications |
| M3.4 | Review and shutdown | The review steps, energy (#130), rollover, shutdown, the workload check (#128) |
| M3.5 | Capture and offline | The ⌥⌘N panel, the toolbar online/queued indicator, the failed-writes sheet |
| M3.6 | Reminders | The reminder model in the API (#127), and the next-block heads-up built on it |

The order is the order the loop is lived: M3.1, then Focus, Timer, Review,
Capture/offline, Reminders. The app becomes a daily driver after M3.3.

## Why M3.1 exists

The M1/M2 client can show today's tasks and toggle completion, and nothing
else. Each missing piece blocks a screen:

- **The timer.** The server stamps `PomodoroSession.started_at` itself
  (`read_only_fields`, `backend/pomodoro/serializers.py`). A session
  finished offline and replayed later would record the time it arrived,
  contradicting the spec: "the timer runs on the Mac … the server receives
  the finished session as a record".
- **Blocks.** Sessions cannot be tied to the block they worked (#129).
- **The review.** It has no `energy` (#130), and it cannot be written safely
  from a queue: a second `POST stats/reviews/` for a date is a 400.
- **Subtasks.** They appear only in a single task's detail response.
- **The store.** Swift caches only `TaskRecord`, with no Kanban status, due
  date, estimate or carried-over flag. There are no blocks, reviews or
  profile.
- **Writes.** The outbox has one write kind and one `onAccepted` callback
  that assumes every reply is a task.

## Decisions (with the user)

- **Kanban moves work offline**, through the outbox like completion. The
  local record mirrors the server's `Task.save` both ways:
  - moving to Done completes the task
  - completing moves it to Done
  - un-completing moves it back to To do This extends the spec's offline loop (L93-101) by one write of the
  same shape.
- **Subtasks are embedded** in `tasks/today/` and `tasks/carried-over/`
  responses: one request, and an additive contract change.
- **The outbox grows by approach A:** a `kind` on each entry, with one small
  handler per kind. The typed command enum was rejected because its switches
  grow with every kind and queued entries would need migrating. Routing by
  path was rejected because it is implicit and fails silently.

## 1. Backend (all additive; old clients keep working)

Every change has its test written first, its contract fixture regenerated
(`WRITE_CONTRACT_FIXTURES=1`), and a `CHANGELOG.md` line (invariant 8).

1. **Sessions keep the Mac's clock** (`backend/pomodoro/`).
   - `started_at` becomes writable. When it is omitted, the server still
     stamps it, so current behaviour is unchanged.
   - The serializer rejects a `started_at` more than 5 minutes in the future
     or more than 8 days in the past. The refresh token lives 7 days, so no
     legitimately queued session is older.
   - It also rejects `ended_at < started_at`.
   - Messages carry the offending value and the expected shape (AGENTS.md).
   - A new nullable FK, `time_block` (`SET_NULL`), records which block a
     session worked (#129). The serializer refuses a block that is not
     `request.user`'s (invariant 1). The test uses two users.
2. **Energy on the review** (`backend/stats/`). `DailyReview.energy` is a
   nullable `PositiveSmallIntegerField`, 1-3, validated in the serializer
   (invariant 3). A database check constraint (`energy` null or 1-3) is
   added as the safety net.
3. **The review is set by date.** `PUT stats/reviews/by-date/<YYYY-MM-DD>/`
   creates or updates the user's single review for that date, and returns
   it.
   - The date goes through `omakase/client_dates.parse_client_date`
     (invariant 2).
   - `shutdown_at` stays server-stamped when `is_shutdown` turns true.
   - A PUT keyed by the natural key (user, date) is idempotent by nature, so
     it needs no `IdempotentCreateMixin`.
   - It lives in `stats/services.py`, with a thin view (AGENTS.md: views
     parse, call, respond).
4. **Subtasks are embedded.** `tasks/today/` and `tasks/carried-over/` tasks
   gain a read-only `subtasks: [{id, title, is_completed, order}]`.
   - They are loaded with `prefetch_related`.
   - A query-count test pins that the embed doesn't add a query per task.
5. **Unchanged, already sufficient:**
   - today's study blocks: `study/studyblocks/?scheduled_date=`
   - today's time blocks: `timeblocks/?date=`
   - the profile: `auth/profile/`

## 2. Swift read side

**OmakaseAPI.** Each DTO is tested by decoding its backend-written fixture,
as in M1.
- `TaskDTO` gains `subtasks: [SubtaskDTO]`. It already decodes
  `kanbanStatus`, `dueDate`, `estimatedMinutes` and `actualMinutes`.
- New DTOs:
  - `TimeBlockDTO` (task XOR study block, date, start and end, notes,
    session rating)
  - `StudyBlockDTO`
  - `PomodoroSessionDTO`
  - `DailyReviewDTO` (with `energy`)
  - `ProfileDTO` (work, short-break and long-break minutes, pomodoros
    before a long break, daily goal hours)
- New `APIClient` calls, each day-shaped one sending `?date=` via `APIDay`:
  - `carriedOver(on:)`
  - `timeBlocks(on:)`
  - `studyBlocks(on:)`
  - `review(on:)`
  - `profile()`

  They reuse M1's paging, refresh-on-401 and error mapping.

**OmakaseStore.** New fields are optional or defaulted, so SwiftData
migrates M1/M2 stores with no hand-written migration.
- `TaskRecord` gains `kanbanStatus`, `dueDay`, `estimatedMinutes` and
  `isCarriedOver`.
- New records:
  - `SubtaskRecord` (belongs to a task; cascade on delete)
  - `TimeBlockRecord`
  - `StudyBlockRecord`
  - `DailyReviewRecord` (one per day)
  - `ProfileRecord` (a single row)

**Sync.** `TodaySync` becomes `DaySync`.
- For the current day it fetches, in parallel (`async let`): today's tasks,
  carried-over tasks, time blocks, study blocks, the review and the profile.
- Each result is applied with M1's rule: **an item with a queued write keeps
  its local state.**
- **Deletions:** a record of that day which the server no longer returns is
  removed, unless it has a queued write or a `local-` id. Without this, an
  item deleted elsewhere lingers on the Mac.
- **The day is recomputed** at every refresh and when the app becomes
  active. This fixes M1's known limitation, the window keeping the day it
  opened on.
- M4's week window reuses `DaySync` per day.

## 3. Swift write side (approach A)

**The entry.** `OutboxEntry` gains `kind: String`, defaulting to
`"task.patch"`, so M1's queued entries stay valid without a migration step.

**The handlers.**
- Each kind has one `OutboxHandler`, which applies the server's reply to its
  records.
- `OutboxWorker`'s `onAccepted` becomes a lookup by kind. **An unknown kind
  parks** with a message naming it, and is never dropped.
- Retry, backoff, park and `local-` placeholder rewriting are unchanged. The
  rewrite already covers a session that refers to a task captured offline.

| Kind | Request | M3 use |
|---|---|---|
| `task.patch` | `PATCH tasks/<id>/` | complete, Kanban column, reschedule (`scheduled_date`: tomorrow, a date, or `null`) |
| `task.create` | `POST tasks/` (idempotent, `local-` id) | capture |
| `subtask.patch` | `PATCH tasks/<id>/subtasks/<id>/` | checking a subtask |
| `block.patch` | `PATCH timeblocks/<id>/` | session notes and rating |
| `session.create` | `POST pomodoro/sessions/` (idempotent) | a finished pomodoro, with the Mac's `started_at` and its block |
| `review.put` | `PUT stats/reviews/by-date/<date>/` | rating, win, energy, shutdown |

**Write functions, by domain:** `TaskWrites` (extended), `SubtaskWrites`,
`BlockWrites`, `SessionWrites` and `ReviewWrites`.
- Each function updates the record and appends its entry **in one SwiftData
  transaction**, as `toggleCompletion` does.
- Each then asks the sync coordinator to catch up at once (#91).

**Deliberately left out:**
- **Coalescing repeated writes to one item.** Ordered replay is correct,
  just chattier.
- **The spec's `inFlight` state** (L103-112). The worker drains serially
  inside one actor, so no second sender can pick up an entry mid-send. The
  parent spec gets a note.

## 4. Testing and delivery

**Issues** (labels `M3`, a type, the areas, and `invariant` where marked):

1. `feat(M3)`: sessions keep the Mac's `started_at` and record their block.
   Refs #129; area:pomodoro, invariant.
2. `feat(M3)`: `energy` on the review. The backend half of #130; the screen
   is M3.4. area:stats.
3. `feat(M3)`: the review is set by date. area:stats, invariant.
4. `feat(M3)`: subtasks embedded in today and carried-over. area:tasks.
5. `feat(M3)`: DTOs and API calls for the day. area:apple.
6. `feat(M3)`: day records and `DaySync`. area:apple.
7. `feat(M3)`: outbox kinds and handlers. area:apple.

**Order:** 1-4 first, each from `develop` and independent of each other,
because they write the fixtures the DTOs decode. Then 5 → 6 → 7, stacked.

**Tests written first.**
- **Backend:**
  - the `started_at` window and `ended_at` ordering, including their
    messages
  - another user's block refused (a two-user test)
  - an omitted `started_at` still stamped
  - `energy` 0 and 4 are 400s
  - the PUT-by-date replayed twice leaves one review with the last values
  - an invalid date in the path is a 400 naming it
  - `subtasks` present and ordered, with the query count flat in the number
    of tasks
  - fixtures regenerated
- **Swift:**
  - every new DTO decodes its fixture
  - `DaySync`:
    - deletes a dropped record
    - keeps a queued or `local-` one
    - recomputes the day across midnight
  - each handler applies its reply to the right record
  - an unknown kind parks
  - an M1 entry with no `kind` replays as `task.patch`
  - a Kanban move to Done marks the local task completed, and un-completing
    moves it to To do (mirroring `Task.save`)

**Before each PR:**
- `backend/gate.sh` and `apps/apple/gate.sh` pass. The Apple gate now runs
  locally (#134).
- Each new or changed endpoint is exercised against the running stack with a
  real JWT (AGENTS.md: the gate is necessary, not sufficient).
- M3.1 adds no UI, so the M1 and M2 `SMOKE.md` lists must still pass on the
  real app.

**Done when:** all seven PRs are merged to `develop` with both gates green in
CI. #129's block link and #130's field exist in the API.

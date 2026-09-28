# M4 Plan: design

**Status:** decided 2026-09-26. The user asked for the run to continue
through the milestones without stopping at each boundary.
**Milestone:** M4 (`docs/ROADMAP.md`). The parent spec is
`2026-09-25-macos-client-design.md`: L75-85 for sync windows, L136-139 for
online-only writes, and L184-190 for Plan. The mockup is
`Mockups/PlanMockupView.swift`.

## What exists

- **Backend:**
  - `TimeBlock` has these fields:
    - `date`, `start_time`, `end_time`
    - `task` XOR `study_block`
    - `notes`, `session_rating`

    Its constraints are end after start and at least one parent. It
    can't cross midnight.
  - `timeblocks/` supports full CRUD, and it filters on `date`,
    `date_from`, `date_to` and `task`. It has **no `IdempotentCreateMixin`**
    and no overlap check.
  - Nothing on the server syncs a parent's `scheduled_date`.
  - `pomodoro/sessions/` can't be listed by time or by block.
  - `study/class-occurrences/` takes a range, up to 90 days.
- **Mac:**
  - Blocks are read for one day. There is no occurrence or session read.
  - `block.patch` carries only notes and rating.
  - `DaySync` loads only today.
  - The only drag and drop is Kanban's `.draggable(String)` with a
    `.dropDestination`.

## Decisions

- **Block writes go through the outbox, and so work offline.** This
  reverses the parent spec's L136-139.
  - That spec made create and move online-only, so that M1 wouldn't need
    placeholder ids for blocks. The outbox now has those, plus dependents,
    retry and discard (M3.1, #184). An online-only path would be a second
    write mechanism, with disabled controls and tooltips to build.
  - New kinds:
    - `block.create`: POST `timeblocks/` with a `local-` id.
    - `block.patch`, extended: day, start, end.
    - `block.delete`.
  - A create the outbox replays must be idempotent, so `TimeBlockViewSet`
    gets `IdempotentCreateMixin` (invariant 9).
- **The parent's `scheduled_date` follows its block.** When a block is
  created, or moved to another day, the same `coordinator.write` also
  queues the parent's `scheduled_date` patch, as the parent spec says.
  - For a task, that's `TaskWrites.reschedule`.
  - Study blocks aren't cached on the Mac until M5, so their date isn't
    synced here, and that is written down.
- **Overlaps are a warning, not a refusal**, as on the web and in IDEA
  §5.3. The client computes them from the local blocks.
  - A drop that overlaps asks "Overlaps *X*. Place anyway?".
  - Overlapping blocks are drawn side by side in lanes.
  - The server stays permissive, since double-booking is allowed.
- **Plan against actual (R8):** focus sessions are drawn at their real
  times, in a thin lane beside the blocks, and not only as a total.
  - `pomodoro/sessions/` gains `?started_after=&started_before=`
    (ISO-8601 instants with offsets, so the client's week is exact in its
    own timezone) and `?time_block=`.
  - Only focus sessions are drawn.
- **The visible range is loaded by a `RangeSync`**, next to `DaySync`:
  the week's blocks, class occurrences and focus sessions. It runs when
  Plan opens, when the visible week changes, and on each catch-up while
  Plan is visible.
  - Sessions and occurrences are cached as read-only records. Nothing
    writes them locally.
  - Class occurrences are never draggable (IDEA §2).
- **The task column** shows what the store holds: today's tasks and the
  carried-over ones. Those are the tasks you plan the day from. A backlog
  and Inbox panel comes with M5's Inbox screen.
- **Grid:**
  - Day and Week views.
  - Hours run 06:00-23:00, scrolled to 08:00. The row height is 52 pt,
    as in the mockup.
  - Snapping is to 15 minutes, and a drop creates a 60-minute block.
  - Blocks show the parent title, and get a 3-pt bar and a faint fill on
    an opaque `surface`, radius small (design-system-apple §Signals).
  - Classes are dashed, with a book glyph, and drawn behind.
  - The now line is a shu dot and line.
  - Delete is from the block's context menu.
  - Colours come from the source where one is cached (a discipline's
    colour for classes). Otherwise the block is `accent` grey.

## 1. Backend (PR K)

- `TimeBlockViewSet(IdempotentCreateMixin, …)`, with a replay test: the
  same `Idempotency-Key` creates one block.
- `pomodoro/sessions/` filters:
  - `started_after` and `started_before` are parsed as aware datetimes,
    and a naive one is a 400 that names the value and the expected shape.
  - `time_block` is a UUID.
  - The queryset is still scoped to `request.user`, with two users
    tested.
- Contract fixtures:
  - `pomodoro_sessions_range.json`
  - `timeblock_create.json`, from an idempotent create
- `CHANGELOG.md` and `docs/ARCHITECTURE.md`.

## 2. Mac data (PR L, reads; PR M, writes)

**L:**
- `APIClient`:
  - `timeBlocks(from:to:)`
  - `classOccurrences(from:to:)`, with `ClassOccurrenceDTO`
  - `focusSessions(from:to:)`, sending instants
- Records: `ClassOccurrenceRecord` and `SessionRecord`.
- `RangeSync.refresh(days:)` replaces the range's rows, and keeps a block
  that has a pending write.

**M:**
- `BlockWrites.create(parent:day:start:end:)` returns a `local-` block and
  queues `block.create`.
- `move(_:day:start:end:)` and `delete(_:)`.
- `BlockHandler` maps the create's placeholder to the server id.
- Parent `scheduled_date` sync, through `TaskWrites.reschedule`.

## 3. Mac UI (PR N1, the read-only calendar; PR N2, interactions)

**N1:**
- `SidebarItem.plan` ("Plan", `calendar`), listed first.
- `PlanModel` holds:
  - the mode (day or week)
  - the anchor day, with today, previous and next
  - the visible days
- `CalendarLayout` is pure:
  - y from a time, and a time from a y, snapped to 15 minutes
  - lanes for overlaps
  - clipping to the visible hours
- `PlanView`: the task column, then the calendar header (title, Today,
  ‹ ›, Day/Week), then the grid with blocks, classes, sessions and the
  now line.

**N2:**
- Drag a task from the column onto a slot to create a block.
- Drag a block to move it, by time or day.
- Drag its bottom edge to resize, in 15-minute steps, with a minimum of
  15.
- Delete from the context menu.
- The overlap confirmation.
- Pure `PlanDrop` math: from a drop point to a day, a start and an end,
  tested.

## Verification

- **Tests first:**
  - The backend with two users.
  - `CalendarLayout` and `PlanDrop` over the edges: the day boundary,
    snapping, the minimum length, and three overlapping blocks.
  - `RangeSync` against the fake client.
  - The block writes against the in-memory store. A create followed by a
    move before replay sends the create, then the move with the server
    id.
- **Real stack:** the new filters and the idempotent create, called with
  curl.
- `SMOKE.md` gains M4.
- Each PR runs `apps/apple/gate.sh` and waits for CI on Xcode 26.6.

## PRs

| # | Issue | Contents | After |
|---|---|---|---|
| K | #199 | Idempotent block create, session range filters, fixtures | - |
| L | #200 | Range reads, records, `RangeSync` | K |
| M | #201 | Block create, move and delete through the outbox, and the parent date | K |
| N1 | #202 | Sidebar Plan, `PlanModel`, `CalendarLayout`, the read-only grid | L |
| N2 | #203 | Drag to create, move and resize, delete, overlap warning, SMOKE, ROADMAP | M, N1 |

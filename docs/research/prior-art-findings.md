# Prior art against our own code

> 2026-09-25. The sibling of `ai-memory`'s
> `prior-art-implementation-findings.md` and omatty's `prior-art-findings.md`:
> it turns everything read in `2026-landscape.md`, the five deep dives and
> the five mining documents into a ledger against Omakase as it actually
> is on `develop` at `51abb80` - M0 and M1 merged.
>
> **Every "we already do this" line names the file that does it**, read in
> this tree, not IDEA.md's description of it. Gaps are P0/P1/P2 and are
> inputs to #105, which is where the roadmap decides. **Analysis only.**

## Executive summary

Omakase's backend already holds the square nobody else holds: work tasks,
study blocks and a class timetable on one set of time blocks, with a
pomodoro record and a daily review beside them. Its architecture already
rules out the two failures that cost competitors the most trust - a sync
merge that drops a dataset, and a desktop app that will not load offline.

What the pass found is that none of that can be used. The client has two
screens. So the gaps below are ranked by one question: does this stand
between a user and the loop, or does it make the loop worth switching to?
The first question outranks everything the field asks for.

## What Omakase already does well, with the file that does it

### Work and study on one set of time blocks

`backend/tasks/models.py` (`TimeBlock`): a block points at a task **or** a
study block, the serializer requires exactly one, and the database requires
at least one (AGENTS.md invariant 3). `backend/study/` holds semesters,
disciplines, study blocks and weekly class schedules. No product in the
landscape's feature table has both halves; the nearest, TickTick, keeps
its timetable in its China edition (`2026-landscape.md` §2). This is the
square, and it is real in the data model.

### Class occurrences computed, never stored

`backend/study/views.py` (`ClassOccurrenceView`) expands each class
schedule into occurrences for a requested range, capped at 90 days. Nothing
is materialised, so there are no duplicate instances to reconcile. That is
the property Super Productivity's recurring tasks lack - its clients each
create instances, which duplicate or go missing
([`issues-super-productivity.md`](issues-super-productivity.md)) - and it
is the pattern R2 reuses.

### A "today" the server cannot get wrong

`backend/omakase/client_dates.py`: `parse_client_date` accepts only
`YYYY-MM-DD` and raises a 400 when the date is missing (line 25), and every
"today" endpoint takes the client's date (invariant 2, #65, #69). The
midnight and timezone cluster appears in four venues
([`issues-synthesis.md`](issues-synthesis.md) §5); the "wrong day" half of
it cannot happen here. The other half - a custom day start, and class
times across a clock change - is not covered (P1-1, P2).

### A write is never lost and never doubled

- `apps/apple/Packages/OmakaseStore/Sources/OmakaseStore/Outbox.swift` and
  `OutboxWorker.swift`: local writes go to an ordered outbox in the same
  SwiftData save as the change; the worker retries with backoff, parks a
  write the server rejects, and parks every write that depends on a
  rejected create (line 83) rather than replaying it into an error.
- `backend/idempotency/services.py`: a replayed create with the same
  `Idempotency-Key` returns the stored response with `Idempotent-Replayed:
  true` for seven days, and the same key on another endpoint is a 422.

Against Super Productivity's last-write-wins sync, which "replaces the
entire losing dataset" (`docs/wiki/3.06-User-Data.md` at `a76c1bc`), and
Sunsama's six-year-old offline request, this is a different category of
guarantee. It covers one list and one action today: ticking a task done
on the Mac.

### Plan date apart from the deadline, and carried-over work

`backend/tasks/models.py` has `scheduled_date` and `due_date` on tasks,
and `backend/study/models.py` the same on study blocks;
`tasks/carried-over/?date=` returns unfinished work scheduled before the
client's day. Users ask for the first in TickTick's and Super
Productivity's venues and for the second in three
([`issues-synthesis.md`](issues-synthesis.md) §8, two-venue table).

### The API is a contract with clients that ship on their own schedule

AGENTS.md invariant 8 and `tools/tests/test_contract_fixtures.py`, which
writes each endpoint's response to `apps/apple/Fixtures/` and fails when
its shape drifts. MyStudyLife's v2 rewrite broke web and mobile sync and
forced account recreation ([`issues-mystudylife.md`](issues-mystudylife.md));
a response shape that changes here fails a test first.

## Gaps and improvement opportunities

### P0-1 - The loop has no client

**Evidence:** every competitor in camps A and C ships its loop in a UI
(`2026-landscape.md` §2); Omakase's row reads "API only".

**Omakase today:** sign-in and a Today checklist
(`apps/apple/Packages/OmakaseFeatures/Sources/OmakaseFeatures/`). A user
cannot timebox, run a timer, or close a day.

**Why P0:** every other gap below improves a product nobody can use yet.
The square is only held once a client stands on it.

**Shape to consider, not to adopt:** none new. `docs/ROADMAP.md` M2 → M3
→ M4 is this gap. The finding is that nothing else in this file outranks
it (R1).

### P0-2 - No recurring tasks

**Evidence:** asked for in all five venues - TickTick, Sunsama (204
votes), Super Productivity (#427, 50 comments), MyStudyLife, Motion and
Reclaim ([`issues-synthesis.md`](issues-synthesis.md) §1).

**Omakase today:** absent from the API and the client. Promised only
(IDEA §2). Only classes recur.

**Why P0 rather than a nice-to-have:** a daily planner without repeats
makes the user re-enter the same work every day. It is the one need all
five venues agree on that the loop itself depends on, since carried-over
work and the morning plan both assume the day's tasks are already there.

**Shape to consider, not to adopt:** a rule on the task, expanded on read
the way `ClassOccurrenceView` expands a class schedule, with only the
exceptions stored (a completed or moved occurrence). Never an instance
created by a client, which is Super Productivity's duplicate bug.

**The honest counter-argument:** a task is heavier than a class. It has a
status, a kanban order, subtasks and time blocks, and a virtual occurrence
that gains any of those has to become a row. That is the exception store,
and it is where the design effort goes.

### P1-1 - The timetable does not survive a real term

**Evidence:** class times drifting after a clock change (MyStudyLife
reviews; Power Planner #73, #90, #127); holidays that do not suppress
classes; Week A/B rotation in every student planner read
([`mystudylife.md`](mystudylife.md), [`issues-mystudylife.md`](issues-mystudylife.md)).

**Omakase today:** `ClassSchedule` has a weekday, a start and an end
time, a type and a location. No holidays, no cancelled occurrence, no
rotation (cancellations and holidays promised, IDEA §3). No test pins
occurrences across a daylight-saving change.

**Why P1:** it does not block the loop, but it is the study half of the
square, and a timetable that is wrong one week in November is abandoned.

**Shape to consider:** the test first; it is a slice on its own and may
find nothing. Then holidays as date ranges on the semester and
cancellation as a stored exception on the computed occurrence, the same
exception store P0-2 needs.

### P1-2 - No reminder model

**Evidence:** four venues ([`issues-synthesis.md`](issues-synthesis.md)
§4).

**Omakase today:** notifications planned for the Mac in M3; nothing in
the API.

**Why P1:** a reminder decided in the Mac client has to be decided again,
differently, on iOS. Platform drift is a five-venue complaint (§2 there).

**Shape to consider:** a reminder as data on a task or time block, served
by the API, scheduled locally by each client.

### P1-3 - No workload check

**Evidence:** the same number computed three ways by Sunsama (workload
threshold, projected finish), Motion (capacity) and Shovel (Time
Cushion), with Sunsama's "actual vs planned" at 402 votes
(`2026-landscape.md` R4).

**Omakase today:** the inputs are in the API - `estimated_minutes`, the
profile's daily work and study goal hours, class occurrences. The check is
promised only (IDEA §6).

**Why P1:** it is the part of auto-scheduling users keep while rejecting
the rest (`2026-landscape.md` §4.2), and it is arithmetic over data
Omakase already stores.

### P1-4 - No phone

**Evidence:** five venues; Shovel and Motion lose users over weak phone
apps ([`issues-synthesis.md`](issues-synthesis.md) §2).

**Omakase today:** iOS and Android are "Later" in `docs/ROADMAP.md`.

**Why P1 and not P0:** the Mac-first order was set for the author's own
daily use, and the three packages are already iOS-ready
(`platforms: [.macOS(.v26), .iOS(.v26)]` in each `Package.swift`). The
gap is real; the order is a decision, not an oversight (R9).

### P2

- **P2-1 Subtasks are second-class.** `Subtask` is a title, a done flag
  and an order, one level (`backend/tasks/models.py`); "subtasks should
  be full tasks" has 905 votes on Sunsama's board and #2657 has 45
  comments in Super Productivity's tracker.
- **P2-2 Estimate against actual.** `estimated_minutes` exists; nothing
  compares it with the time blocks worked (Sunsama, 402 votes; promised
  IDEA §9).
- **P2-3 A day that ends after midnight.** No day-start setting (Sunsama
  152 votes, closed; TickTick's board).
- **P2-4 Undo and trash.** No undo, no trash; destructive defaults are a
  TickTick data-loss cluster ([`issues-ticktick.md`](issues-ticktick.md)).
- **P2-5 Bulk edit.** Only `tasks/reorder-bulk/` (Sunsama 277 votes).
- **P2-6 An energy field on the review.** Super Productivity's finish-day
  records impact (1-4) and energy (1-3); Omakase's `DailyReview` has a
  1-5 rating and a win of the day, and IDEA §13's energy mapping has no
  data source (R10).
- **P2-7 macOS target.** 26 in `apps/apple/project.yml` while 27 shipped
  on 2026-09-14 (R7).

## Ideas Not To Copy

| Idea | Where it ships | Why not |
|---|---|---|
| Auto-scheduling with locks that expire | Motion (a lock moves after 60 minutes, [task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)) | Churn and loss of control are Motion's top structural complaints, and Reclaim 2.0 retreated from it. The morning plan suggests; the user places. |
| Recurring instances created by each client | Super Productivity | Duplicates and misses (#427, #6230 there). Compute on the server (P0-2). |
| Last-write-wins sync of the whole dataset | Super Productivity (`docs/wiki/3.06-User-Data.md`) | "replaces the entire losing dataset". The server serialises writes; the outbox replays them. |
| Rituals or timers on one client only | Akiflow (focus timer "Desktop only"), Ellie (rituals not on iPhone), Sunsama (focus bar needs the desktop app) | The loop is the product. A step that exists on one device is a loop that breaks when the user changes device. |
| Paywalling the planning surface | TickTick (calendar views and timed tasks are Premium) | The calendar is where the square is. Gating it gates the reason to switch. |
| A rewrite that forces account recreation | MyStudyLife v2 ([`issues-mystudylife.md`](issues-mystudylife.md)) | Invariant 8 exists for this. |
| An AI chat planner | Every first party this quarter (`2026-landscape.md` §4.1) | Capture by sentence is free on the user's phone; competing with the calendar owners on it is not the job. |
| Streaks that punish a missed day | Lunatask (habits with streaks), TickTick (habit tracker) | One venue asks for habits. IDEA §15's streak freezes exist because streaks punish; better not to lead with them. |

## Corrections this pass owes other issues

- **#51 is already fixed.** "tasks/today/ should 400 on missing date param"
  is open, and `parse_client_date` raises a 400 on a missing date
  (`backend/omakase/client_dates.py:25`), shipped by #65 and #69. It can
  be closed with a pointer to them.
- **Several open issues predate the removal of the web client (#62).**
  #57 (publish backend and frontend images) and #59 (a Playwright suite)
  name the frontend; #50 ("Build native macOS app") is what M1-M6 now
  are. They describe a product that no longer exists and should be
  re-read against `docs/ROADMAP.md`. This pass records them; it does not
  close them.
- **`docs/design-system.md` describes the web client** ("Sunsama-style
  productivity layout"). M2's identity replaces it; until then it is the
  only document that names a competitor as a model, and the model it
  names ships no study half.

## Bottom line

The backend is further ahead of the field than any client could show: the
square is in the data model, and the two worst failure classes in the
field are designed out. The client is behind every competitor read. The
roadmap's own order - M2, M3, M4 - is P0-1, and recurring tasks are the
one thing the field agrees on that the loop needs and nobody has planned.

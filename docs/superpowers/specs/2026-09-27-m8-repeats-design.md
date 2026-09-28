# M8 Repeats and exceptions: design

**Status:** decided 2026-09-27. The run continues through the milestones
without stopping.
**Milestone:** M8 (`docs/ROADMAP.md`). **Issues:** #124 (recurring tasks),
#125 (holidays and cancelled classes), #126 (Week A/B rotation).

## The principle

One rule for both apps:

- A repeat is a **rule** that is expanded on read, for a client date range
  (invariant 2).
- Only **exceptions** are stored, each keyed by (rule, date) with a
  uniqueness constraint.
- Clients never create instances, so an occurrence can't be duplicated or
  lost. Super Productivity's #427 and #6230 happen because its clients
  create instances.

The roadmap's "same exception store" is this principle, not a shared
table. `tasks` and `study` may not import each other (the import-linter
independence contract), so each app keeps its own exceptions under the
same rule.

## 1. Classes: rotation, holidays, cancellations (#125, #126)

All three live in `study/services.class_occurrences`, the one expansion
function (#176).

**Rotation (#126):**
- `Semester.rotation_weeks`: 1-4, default 1.
- `Semester.rotation_anchor`: a date, null meaning the semester's
  `start_date`.
- `ClassSchedule.rotation_weeks_on`: a JSON list of week numbers, where an
  empty list means every week.
- The week number is
  `((monday(date) - monday(anchor)).days // 7) % rotation_weeks + 1`.
- The serializers validate that each listed week is within
  1..rotation_weeks (invariant 3).

**Holidays (#125):**
- `Holiday(semester, name, start_date, end_date)`, with a check that
  `end >= start`.
- CRUD at `study/holidays/`, scoped through the semester (invariant 1).
- Expansion skips every date inside a holiday.

**Cancellations (#125):**
- `ClassCancellation(class_schedule, date)`, unique on the pair.
- `PUT study/classschedules/<id>/cancellations/<date>/` cancels a class
  on that date, and `DELETE` restores it.
  - The date must be an occurrence of that schedule, or the request is a
    400.
  - Both are idempotent by their natural key, so neither needs
    `IdempotentCreateMixin`.
- Cancelled occurrences are **returned with `is_cancelled: true`**, not
  omitted. A cancelled class is information, and the calendar strikes it
  through. Holidays omit their dates, because a holiday is the absence of
  term.

The occurrence response's new keys are `is_cancelled` and `week`. They are
additive, and the fixtures are regenerated.

## 2. Recurring tasks (#124)

**The series:**
- A task with a `TaskRecurrence` (one-to-one) is a **series**. The series
  task is the template: its title, priority, estimate, project and tags
  are copied to each occurrence.
- `TaskRecurrence` fields:
  - `freq`: daily, weekly or monthly
  - `interval`: 1-30
  - `weekdays`: for weekly, 0=Mon..6=Sun; empty means the start date's
    weekday
  - `starts_on`: the first date
  - `until`: nullable
- A monthly rule on day N skips months that have no day N (the 31st), as
  RFC 5545 does.

**The exception is a concrete row:**
- An occurrence is **virtual** until something writes to it: completing it,
  moving it, editing it, adding a block or a subtask, or skipping it.
- It becomes a real `Task` with `series` (FK to the series task) and
  `occurrence_date`. `UniqueConstraint(series, occurrence_date)` means there
  can never be two.
  - `scheduled_date` is independent, so a moved occurrence keeps its
    identity.
  - `is_skipped` marks a skipped occurrence.
- `PUT tasks/<series>/occurrences/<date>/` is the materialize call.
  - It does a get-or-create on (series, date), copying the template, and
    returns the task.
  - It is idempotent by the natural key, so the outbox can replay it.
  - The date must be an occurrence of the rule, or the request is a 400.

**Reads:**
- `tasks/today/?date=D` returns:
  - the concrete tasks scheduled on D, excluding series templates and
    skipped rows
  - plus every series' virtual occurrence on D that has no concrete row

  A virtual item is task-shaped, with:
  - `id: null`
  - `series: <uuid>`
  - `occurrence_date: D`
  - `is_virtual: true`
  - `subtasks: []`
- `tasks/occurrences/?date_from=&date_to=` does the same over a range, capped
  at 62 days, for Plan.
- `tasks/carried-over/` **includes only concrete rows.** An untouched
  virtual occurrence in the past lapses; it doesn't pile up. A daily
  repeat you missed on Monday is not two tasks on Tuesday. A concrete row
  that was started and left unfinished carries over like any task.
- Series templates are hidden from `today/`, `carried-over/` and
  `workload`, but listed by `tasks/` with `recurrence` embedded, so the
  client can edit the rule.

**Writes:**
- `PUT tasks/<id>/recurrence/` sets the rule.
  - On a task that isn't yet in a series, it creates a new hidden template
    copied from the task, and attaches the rule to the template.
  - The task itself stays the first concrete occurrence: `series` is the
    template, and `occurrence_date` is its `scheduled_date`, or
    `starts_on` if it had none. Its blocks, subtasks and completion stay
    where they are.
  - On an occurrence or a template, it updates the series' rule.
  - The response is the task, with `series` and the embedded
    `recurrence`.
- `DELETE tasks/<id>/recurrence/` ends the series by setting `until` to the
  day before the client's `?date=`. It never deletes history, and it hides
  the template.

**What changes for invariant 2:** "today" now includes computed items, and
"carried over" excludes lapsed virtual ones. The CHANGELOG names both, and
`tasks_today.json` gains the virtual fields (`id` may be null).

## 3. Mac (PRs S, T)

**Tasks:**
- `TaskDTO` decodes `id: String?`, `series`, `occurrenceDate` and
  `isVirtual`. A virtual occurrence is stored as a `TaskRecord` with the
  stable local id `occ-<series>-<date>`.
- The first write on a virtual record queues `task.materialize` (a PUT)
  with `createsLocalID = occ-…`, so the outbox's placeholder rewrite gives
  every later write the server id. This is the mechanism `local-` ids
  already use.
- A "Repeat" menu on the Focus task panel offers Daily, Weekdays,
  Weekly on <weekday>, Monthly on day N, and Stop repeating. It queues
  `task.recurrence` as a PUT or a DELETE.
- Focus and Plan show a repeat glyph (`repeat`, inkMuted) on occurrences.
- Plan loads `tasks/occurrences/` for its range.

**Classes:**
- The occurrence DTO and record gain `isCancelled`.
- Plan draws a cancelled class struck through and dimmed.
- The class context menu offers "Cancel this class" and "Restore". These
  are outbox kinds `class.cancel` (PUT) and `class.restore` (DELETE),
  idempotent by path.
- Holidays and rotation have no Mac UI in M8. They are edited in M5's
  Study screens. M8 exposes the API, and the calendar shows the result.

## PRs

| # | Issue | Contents | After |
|---|---|---|---|
| O | #125, #126 | Backend study: rotation, holidays, cancellations, expansion, fixtures | - |
| P | #124 | Backend tasks: TaskRecurrence, series and occurrence fields, materialize, recurrence PUT/DELETE, virtual items in today/ and occurrences/, fixtures | O (checkout) |
| S | #206 | Mac: recurring occurrences, materialize, Repeat menu | P, M4 |
| T | #207 | Mac: cancelled classes shown, cancel and restore | O, M4 |

## Verification

- **Backend tests first**, with two users throughout.
- **Rotation:** the week index across a year boundary, and a rotation of
  2 with the anchor mid-week.
- **Holidays:** at the edges (start and end dates inclusive).
- **Cancellations:**
  - A cancel on a non-occurrence date is a 400.
  - A second PUT is a no-op.
- **Recurrence:**
  - Daily, weekly with several weekdays, monthly on the 31st, `until`,
    and interval 2.
  - A materialize twice gives one row.
  - A moved occurrence appears on its new date and not its old one.
  - A skipped occurrence disappears.
  - `carried-over` excludes virtual occurrences and includes a started
    concrete one.
  - `workload` counts virtual occurrences' estimates.
  - A query-count test pins the expansion to a constant number of queries.
- **Mac:**
  - Materialize, then patch, replays in order, with the patch rewritten
    to the server id.
  - Discarding a parked materialize removes the local occurrence's
    changes.
- **Real stack:** curl each new endpoint with a real JWT.

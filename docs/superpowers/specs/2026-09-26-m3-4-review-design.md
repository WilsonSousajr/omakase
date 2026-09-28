# M3.4 Review and shutdown: design

**Status:** decided 2026-09-26 under the milestone-checkpoint rule (the user
reviews M3 as a whole when M3.6 lands).
**Milestone:** M3, "The daily loop" (`docs/ROADMAP.md`); slice table in
`2026-09-26-m3-1-data-foundation-design.md`.
**Issues:** #128 (workload), #130 (energy), #176-#179.

## What exists

M3.1 built the data this screen needs:

- `PUT stats/reviews/by-date/<day>/` exists, and so does the `review.put`
  outbox kind (`ReviewWrites.save`, `ReviewHandler`).
- `DailyReviewRecord` and `ProfileRecord` are in the store.
- `TaskRecord` carries `estimatedMinutes` and `isCarriedOver`.
- `TaskWrites.reschedule` queues a `task.patch` with `scheduled_date` or
  null.

Nothing calls `ReviewWrites` yet. The sidebar has one item, Focus.

Missing pieces:

- There is no endpoint that sums the day's planned load (#128).
- The client has no class occurrences.
- There is no Review screen.

## Decisions

- **Workload is computed on the server** (#128). It is a read,
  `GET stats/workload/?date=`, so iOS gets the same number without
  re-deriving it. The Mac caches the last answer for offline use.
- **Rollover needs no new endpoint.** Each unfinished task is one
  `task.patch` through the outbox, which is the reschedule Focus already
  uses.
  - A bulk endpoint would need its own lock and bound (invariant 6) and
    save nothing: a day has a handful of unfinished tasks, and the outbox
    replays them in order.
  - The choices follow IDEA §8: tomorrow (the default), a chosen date, or
    the backlog.
  - "Cancel" is left out. There is no cancelled state and no delete write
    kind, and deleting from a review is destructive.
- **Only tasks roll over in M3.4.** Study blocks and the Study screen come
  in M5. A study block left unfinished stays on its date, and the review
  shows it.
- **One screen, with steps in order, not a wizard.** The Review screen is
  one scrolling column:
  1. The day's summary.
  2. Rollover.
  3. Rating (1-5), energy (1-3, #130) and the win of the day.
  4. Shut down.

  Every field is optional; only "Shut down" writes `is_shutdown`. Each
  change is saved (debounced) through `review.put`, so quitting halfway
  loses nothing.
- **Shutdown applies the rollovers.** When you shut down, the review is
  written with `is_shutdown: true`, and the day's rollover choices are
  queued in one `coordinator.write`. After shutdown the screen shows "Day
  closed" and a Reopen action, which writes `is_shutdown: false`.
- **The workload warning lives in the Focus header**, where the day is
  planned. It shows the planned total against the goal. It warns when the
  total is over, and says when it is partial because some items have no
  estimate. It never moves anything.

## 1. Backend

### 1.1 `study/services.class_occurrences` (refactor)

`ClassOccurrenceView`'s loop moves into
`study/services.py: class_occurrences(user, start, end) -> list[dict]`,
unchanged, and the view becomes parse, call, respond. The existing tests
must pass unmodified. M8's exceptions will sit in the same function.

### 1.2 `GET stats/workload/?date=YYYY-MM-DD` (#128)

The date goes through `parse_client_date` (invariant 2). The endpoint reads
only the user's data (invariant 1), and the logic is in
`stats/services.py: day_workload(user, day)`.

```json
{
  "date": "2026-09-26",
  "task_minutes": 150,
  "study_block_minutes": 60,
  "class_minutes": 90,
  "planned_minutes": 300,
  "goal_minutes": 720,
  "over_minutes": -420,
  "unestimated_count": 2
}
```

- `task_minutes`: the sum of `estimated_minutes` over tasks with
  `scheduled_date == day`, done or not, since the whole plan counts. Tasks
  carried over into the day don't count until they are rescheduled onto it.
- `study_block_minutes`: the same, over study blocks.
- `class_minutes`: the sum of `end - start` over
  `class_occurrences(user, day, day)`.
- `goal_minutes` is `(daily_work_goal_hours + daily_study_goal_hours) × 60`.
  The profile row is created with defaults if it is missing, as
  `auth/profile/` does.
- `over_minutes` is `planned - goal`. It is negative when there is headroom.
- `unestimated_count` counts the tasks and study blocks with no estimate.
  #128's counter-argument asks for it, so the warning can say it's
  partial.

This is additive, so old clients are unaffected. It gets a contract fixture
(`stats_workload.json`) and a `CHANGELOG.md` line.

## 2. Swift

- **OmakaseAPI:** `WorkloadDTO` decodes the fixture, and
  `APIClient.workload(on:)` sends `?date=` via `APIDay`.
- **OmakaseStore:**
  - A `WorkloadRecord` keyed by `day`.
  - `DaySync` fetches the workload as its seventh request, for the same
    day computed once, and `DayApply.workload` upserts it.
  - A rollover helper queues one `task.patch` per choice (tomorrow, a
    date, or backlog), reusing `TaskWrites.reschedule`.
- **OmakaseFeatures:**
  - `SidebarItem.review` ("Review", `moon.stars`).
  - `ReviewModel` (`@Observable @MainActor`, injected `Actions`, like
    `FocusModel`) holds the draft: rating, energy, win, and a rollover
    choice per unfinished task. It reads the day's records and saves
    through `Actions.save`, debounced. `shutDown()` calls
    `Actions.shutDown(review, rollovers)`, and `reopen()` calls
    `Actions.save` with `shutdown: false`.
  - `ReviewSummary`, a pure function, gives the planned count, the done
    count, the estimated and actual minutes of the done tasks, and the
    unfinished tasks. It is tested without SwiftUI.
  - `ReviewView` is the single column above, using the design system:
    sectionLabel headings, surface cards, the ink primary for Shut down,
    and glass for the rest.
  - `WorkloadBanner` is a pure `WorkloadWarning` value (none, under, over,
    or partial) plus its view in the Focus header.
- **OmakaseMac:**
  - The detail becomes a `switch section`.
  - `AppServices.reviewActions` wires `ReviewWrites` and the rollover
    through `coordinator.write`, as `focusActions` does.

## 3. Verification

- **Tests first**, and each bug found gets a regression test named after
  its issue.
- **Backend:**
  - Two users, to prove scoping.
  - A day with classes from two schedules.
  - A day with no profile row.
  - Tasks with no estimate.
  - A task done today, which still counts.
  - A carried-over task, which doesn't count.
- **Swift:**
  - `ReviewSummary` and `WorkloadWarning` are pure.
  - `ReviewModel` is tested with fake `Actions`: shutdown queues the
    review and then one reschedule per choice, and reopen clears it.
  - The rollover writes are checked against a fake transport, one
    `task.patch` each, in order.
- **Real stack:** the workload endpoint is called with a real JWT. Then the
  app is rebuilt, and the review is taken in it:
  1. Rate the day.
  2. Roll a task to tomorrow.
  3. Shut down.
  4. Check `stats/reviews/?date=` and the task's `scheduled_date` with
     curl.
- `SMOKE.md` gains `## M3.4`.

## 4. PRs

| # | Issue | Branch | Contents |
|---|---|---|---|
| A | #176 | `refactor/176-class-occurrences-service` | 1.1 |
| B | #128 | `feat/128-workload-endpoint` | 1.2, fixture, CHANGELOG; this spec and plan |
| C | #177 | `feat/177-workload-mac` | WorkloadDTO, the call, the record, DaySync, the Focus banner |
| D | #178 (+ #130 UI) | `feat/178-review-screen` | sidebar, ReviewModel, ReviewSummary, ReviewView, saving |
| E | #179 | `feat/179-rollover-shutdown` | rollover choices, shutdown and reopen, SMOKE, ROADMAP |

A and B run in order in the main checkout: the dev container mounts it. C
waits for B's fixture. D can run beside A and B in a worktree. E builds on
D.

**Done when:** A-E are merged with both gates green, and the M3.4 smoke run
passes in the real app.

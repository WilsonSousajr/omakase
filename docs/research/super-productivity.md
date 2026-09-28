# Super Productivity - deep dive

> Captured **2026-09-25**. Every load-bearing claim below was checked against
> a live primary page on that date, not remembered.
>
> Read at code level: the repository
> [`super-productivity/super-productivity`](https://github.com/super-productivity/super-productivity)
> (the old `johannesjo/super-productivity` URL redirects there; the GitHub
> API returns `full_name: super-productivity/super-productivity`), shallow
> clone at commit `a76c1bccea42f091ed42b1c48d7e78686247caa4` (committed
> 2026-09-25 21:10 +0200). Every path in backticks is relative to that tree.
> Pricing was read on [super-productivity.com](https://super-productivity.com/)
> and its [pricing page](https://super-productivity.com/pricing/).
>
> Coverage limits: SuperSync hosted pricing is not published anywhere that
> was found. The app itself was not run; behaviour is read from code, the
> repository's docs and its wiki pages under `docs/wiki/`. What its users
> ask for is in [`issues-super-productivity.md`](issues-super-productivity.md).
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## 1. Purpose and target user

It describes itself as "An advanced todo list app with timeboxing & time
tracking capabilities that supports importing tasks from your calendar,
Jira, GitHub and others" (`README.md`).

`funding.json` names its users as "developers, freelancers, students, and
focus-driven workers who need serious task and time tracking". The same file
claims 19k+ stars, 90k+ Google Play installs at 4.8 stars, and 99 recurring
GitHub Sponsors. These numbers are vendor-self-reported.

The stack is an Angular and NgRx web app (`@angular/core` and `@ngrx/store`
in `package.json`), packaged by Electron (`electron/`) for desktop and by
Capacitor (`capacitor.config.ts`, `android/`, `ios/App`) for mobile. It is
one codebase.

The work context is `PROJECT | TAG`
(`src/app/features/work-context/work-context.model.ts`). There is one
work/personal axis and nothing that models study.

## 2. Data model

**Task** (`src/app/features/tasks/task.model.ts`, base fields in
`packages/plugin-api/src/types.ts`):

- Hierarchy is `projectId`, `tagIds`, `parentId` and `subTaskIds`. Subtasks
  are one level deep; the open issue
  [#2657](https://github.com/super-productivity/super-productivity/issues/2657)
  "Task Hierarchies (Sub tasks for sub tasks)" has 45 comments.
- Time is `timeEstimate`, `timeSpent` and `timeSpentOnDay: {[YYYY-MM-DD]: ms}`.
  Time is stored per day on the task itself. There is no session table.
- The plan date is `dueDay` (YYYY-MM-DD) or `dueWithTime` (epoch ms). The
  two are mutually exclusive (ADR #1 in `ARCHITECTURE-DECISIONS.md`).
- Deadlines are separate fields: `deadlineDay`, `deadlineWithTime` and
  `deadlineRemindAt`.
- Also `priority` (`'high'|'medium'|'low'`), `remindAt`, `repeatCfgId`,
  `attachments`, and issue-tracker fields (`issueId`, `issueType`,
  `issueTimeTracked` and others).

**Project** (`src/app/features/project/project.model.ts`) holds `taskIds`,
`backlogTaskIds`, `noteIds`, `isArchived`, `isDone`/`doneOn`, a theme and
`issueIntegrationCfgs`. Order is stored as id arrays on the parent; there is
no per-task order field. **Tag** (`src/app/features/tag/tag.model.ts`) shares
`WorkContextCommon` with Project.

**TODAY is a virtual tag** (`src/app/features/tag/tag.const.ts`; ADR #2).
Membership comes from `task.dueDay`; `TODAY_TAG.taskIds` stores only the
order of today's tasks.

**Repeat config**
(`src/app/features/task-repeat-cfg/task-repeat-cfg.model.ts`): cycles
`DAILY|WEEKLY|MONTHLY|YEARLY` with `repeatEvery` and weekday booleans;
monthly anchors on the Nth weekday
([#6040](https://github.com/super-productivity/super-productivity/issues/6040))
and the last day
([#7726](https://github.com/super-productivity/super-productivity/issues/7726)).
Other fields: `startTime`, `defaultEstimate`, `repeatFromCompletionDate`,
`waitForCompletion`, `skipOverdue`, `deletedInstanceDates` (an exception
list), `subTaskTemplates` and `isPaused`.

**Time-tracking aggregates**
(`src/app/features/time-tracking/time-tracking.model.ts`) have the shape
`project|tag -> date -> {s,e,b,bt}`: work start, work end, break count and
break time, per context per day.

**Other entities:** a metric per day
(`src/app/features/metric/metric.model.ts`), notes, boards
(`src/app/features/boards`), and habits as simple counters
(`src/app/features/simple-counter`, route `habits` in
`src/app/app.routes.ts`).

**Study concepts:** none. A grep of `src/app` for
`student|semester|school|lecture|timetable` matches only
`src/app/ui/material-icons.const.ts`, which holds icon names.

## 3. Planning surface

**Planner** (`src/app/features/planner/`, route `planner`) is a day-by-day
column list. `PlannerDay` in `planner.model.ts` holds `tasks`,
`deadlineTasks`, `noStartTimeRepeatProjections`, `allDayEvents`,
`scheduledIItems`, `timeEstimate`, `timeLimit`, `availableHours` and
`progressPercentage`. Future repeat instances are shown as projections
(`ScheduleItemType.RepeatProjection`, `planner-repeat-projection/`); they are
not stored as tasks.

**Schedule** (`src/app/features/schedule/`, with `schedule-week/` and
`schedule-month/`) is computed, not hand-placed:

- `src/app/features/schedule/map-schedule-data/create-schedule-days.ts`
  takes the unscheduled tasks, gives any task without an estimate a minimum
  duration (`SCHEDULE_TASK_MIN_DURATION_IN_MS`), and flows them in sequence
  around blocked time.
- Blocked time comes from `create-blocked-blocks-by-day-map.ts` in the same
  folder: calendar events, fixed-time tasks, work start and end, and lunch.
- A task that does not fit is split across the gap (`SVEType.SplitTask`,
  `SplitTaskContinued`), and the rest rolls to the next day
  (`SVEEntryForNextDay`). Over-budget tasks come from
  `get-tasks-within-and-beyond-budget.ts`.
- The work window is configuration: `schedule.workStart`, `workEnd: '17:00'`
  and an optional lunch break
  (`src/app/features/config/default-global-config.const.ts`).

**Time blocking** means setting a task's `dueWithTime`. There is no block
entity apart from the task, so a task occupies at most one slot.
[#5643](https://github.com/super-productivity/super-productivity/issues/5643)
"Differentiate Scheduled Work Time and Due Date" is closed, and deadlines
are now separate fields (§2).

**Boards:** Kanban and Eisenhower (`src/app/features/boards`; `README.md`).

## 4. Daily ritual

**Start of day.** No guided "plan your day" flow was found in the code.
`src/app/features/tasks/store/task-due.effects.ts` calls
`AddTasksForTomorrowService.addAllDueToday()`
(`src/app/features/add-tasks-for-tomorrow/add-tasks-for-tomorrow.service.ts`)
whenever `todayDateStr$` changes, after the initial sync, which moves due
and repeating tasks into TODAY. A code comment there records a known gap
([#6230](https://github.com/super-productivity/super-productivity/issues/6230)):
if the trigger is missed around midnight or sleep, repeat tasks do not
appear until the next date change or a restart.

**End of day.** "Finish day" is
`src/app/pages/daily-summary/daily-summary.component.ts`, route
`daily-summary` in `src/app/routes/context.routes.ts`. `finishDay()`:

1. runs the `BeforeFinishDayService` actions
   (`src/app/features/before-finish-day/before-finish-day.model.ts`), which
   take a `dayStr` because a past day can be finished too;
2. waits up to 30 s for sync;
3. moves done tasks to the archive (`_moveDoneToArchive` ->
   `taskService.moveToArchive`);
4. on Electron, offers to quit the app (`window.ea.shutdownNow()`).

The summary page also shows the evaluation sheet
(`src/app/features/metric/evaluation-sheet/`), which records `impactOfWork`
1-4, `energyCheckin` 1-3, notes and `reflections`
(`src/app/features/metric/metric.model.ts`); the simple counters; "plan
tasks tomorrow" (`src/app/pages/daily-summary/plan-tasks-tomorrow/`); and the
day's work start and end, which can be edited (`updateWorkStart`).

`src/app/features/finish-day-before-close/` prompts the user to finish the
day before the app closes.

## 5. Focus

**Focus mode** (`src/app/features/focus-mode/`) has three modes,
`FocusModeMode = Flowtime | Pomodoro | Countdown` (`focus-mode.model.ts`),
implemented as strategy classes in `focus-mode-strategies.ts`.

- Pomodoro defaults are 25/5/15 minutes with 4 cycles before the long break
  (`pomodoro` in `src/app/features/config/default-global-config.const.ts`).
- Flowtime breaks are a ratio (`breakPercentage: 20`).
- `isPauseTrackingDuringBreak: true` pauses tracking during breaks.
- Timer state is a single `TimerState` with `purpose: 'work'|'break'`,
  stored locally (`focus-mode-storage.service.ts`). A focus session is not a
  synced record; only a count, `focusSessions?: number[]`, lands on the
  per-day metric.

**Time tracking.** A shared 1-second tick
(`src/app/core/global-tracking-interval/global-tracking-interval.service.ts`)
dispatches `TimeTrackingActions.addTimeSpent`, which increments
`timeSpentOnDay[today]` on the current task
(`src/app/features/tasks/store/task-electron.effects.ts`,
`task-related-model.effects.ts`). On Android the tick stops in the
background and the gap is reconciled from a native counter (comment in the
same code, citing
[#8243](https://github.com/super-productivity/super-productivity/issues/8243),
battery drain).

**Idle detection** (`src/app/features/idle/`) defaults to 5 minutes
(`idle.minIdleTime`). The desktop uses Electron plus
`electron/wayland-idle-helper`; the web app needs a Chrome extension
(`docs/wiki/3.05-Web-App-vs-Desktop.md`).

**Break reminder**
(`src/app/features/take-a-break/take-a-break.service.ts`) fires after
`takeABreakMinWorkingTime` of 60 minutes, snoozes for 15, and can lock the
screen or show a timed full-screen blocker.

**"Domina mode"** reads the current task's title aloud every 5 minutes
(`dominaMode` in the default config).

## 6. Study features

None (§2). The nearest pieces are habits as simple counters, repeat configs
(which could stand in for a class schedule) and iCal/CalDAV import (which
could show a timetable as calendar events). There is no semester, course or
discipline, no class or occurrence entity, and no study-block type.

## 7. Analytics

- **Metric page** (`src/app/features/metric/`, route via
  `src/app/pages/metric-page`): `SimpleMetrics` in `metric.model.ts` covers
  time spent against estimate, break count and time, tasks done, and
  averages per day and per task. It also has an activity heatmap
  (`activity-heatmap/`), a productivity breakdown dialog, impact stars and a
  score (`metric-scoring.util.ts`).
- **Worklog** (`src/app/features/worklog/`): week and month history built
  from `timeSpentOnDay` and the archive. Export (`worklog-export/`,
  `dialog-worklog-export/`) produces timesheets.
- **Per repeat series:** a heatmap and time spent
  (`src/app/features/task-repeat-cfg/repeat-task-heatmap/`,
  `calc-repeat-task-series-time-spent.util.ts`).
- **Per project:** completion stats
  (`src/app/features/project/project-completion-stats.util.ts`).

## 8. Platforms, native or not, offline

**Platforms.** Electron on desktop (`electron/`, `electron-builder.yaml`;
Flathub, Snap, Microsoft Store and the Mac App Store are listed in
`README.md`). The web app at app.super-productivity.com is a PWA
(`ngsw-config.json`) and also ships as a Docker image. Android and iOS run
through Capacitor. None of the clients is native UI; each is the same
Angular app in a shell.

**The web build is weaker** (`docs/wiki/3.05-Web-App-vs-Desktop.md`): no
local file sync, CalDAV and WebDAV hit CORS, tracking works only while the
tab is open, and storage persistence is a browser request that can be
denied.

**Local storage** is IndexedDB (`SUP_OPS`) on every platform. A move to
native SQLite is designed but "not wired"
(`docs/sync-and-op-log/sqlite-migration.md`,
[#7892](https://github.com/super-productivity/super-productivity/issues/7892),
[#7931](https://github.com/super-productivity/super-productivity/issues/7931)),
and that document notes WebView IndexedDB "can be lost if WebView storage is
evicted". The home page says "No account needed · Works offline"
([super-productivity.com](https://super-productivity.com/)).

**Sync is an operation log** (`src/app/op-log/`,
`docs/sync-and-op-log/README.md`, `operation-log-architecture.md`):

- Persistent NgRx actions are captured as operations carrying vector
  clocks, pruned to `MAX_VECTOR_CLOCK_SIZE = 20` (ADR #10).
- Remaining conflicts are resolved last-write-wins, with a disjoint-field
  auto-merge (`src/app/op-log/sync/conflict-disjoint-merge.util.ts`).
- When automatic resolution meets changes it cannot merge, sync stops with
  `SYNC_MULTI_ENTITY_UNSUPPORTED` (`docs/wiki/3.08-Sync-Integration-Comparison.md`,
  `src/app/op-log/core/errors/sync-errors.ts`); the user then picks Keep
  local or Keep remote, and "Either choice replaces the entire losing
  dataset, not just the conflicting entities" (`docs/wiki/3.06-User-Data.md`).
- A conflict journal and review page exist
  (`src/app/pages/sync-conflicts-page/`) but are disabled in production
  (`disableConflictJournal: true`, per
  `docs/sync-and-op-log/conflict-journal-and-review.md`). The same document
  says the journal "is also not a no-silent-loss guarantee".

**Sync providers** (`docs/wiki/3.08-Sync-Integration-Comparison.md`,
`src/app/op-log/sync-providers/`): Nextcloud, WebDAV, Dropbox, a local file
(desktop only, single writer), and SuperSync (beta). SuperSync is the
project's own server (`packages/super-sync-server/`, Postgres and Prisma)
with optional end-to-end encryption. The file providers are only as atomic
as the backend's ETag or compare-and-swap support allows.

SuperSync's upload
(`packages/super-sync-server/src/sync/services/operation-upload.service.ts`)
deduplicates retries by a client-generated operation id ("Check for
duplicate operation before conflict checks"). ADR #10 declines server-side
entity versioning, because the file providers have no server to run it.

## 9. Pricing and student plans

"Super Productivity is 100% free. No trials, no premium tiers, no hidden
costs" ([pricing](https://super-productivity.com/pricing/)). The home page
says "Free. Open source. Yours."
([super-productivity.com](https://super-productivity.com/)). It is funded by
GitHub Sponsors (`funding.json`). There is no student plan, because there is
nothing to discount.

**Not verified: SuperSync hosted pricing.** The pricing page does not
mention SuperSync. The server has a per-account `storageQuotaBytes` default
(`packages/super-sync-server/src/auth.ts`,
`packages/super-sync-server/src/sync/services/storage-quota.service.ts`),
and its terms of service have a "Prices and Payment Terms" section for "Paid
features" (`packages/super-sync-server/legal/terms-of-service-en.md` §8). A
paid tier is anticipated in the legal text; no price is published.

## 10. Integrations

- **Built in** (`BUILT_IN_KEYS` in `src/app/features/issue/issue.model.ts`;
  providers in `src/app/features/issue/providers/`): Jira, GitLab, CalDAV,
  iCal, OpenProject, Redmine, Nextcloud Deck and Plainspace.
- **Moved to plugins** (`packages/plugin-dev/`): GitHub, ClickUp, Gitea,
  Linear, Trello and Azure DevOps, plus Google Calendar
  (`google-calendar-provider`), a CalDAV calendar provider and a Todoist
  import.
- Calendar writes live only in plugins, behind a per-provider opt-in (ADR #9
  in `ARCHITECTURE-DECISIONS.md`).
- Time on an issue can be written back as worklogs (`issueTimeTracked` on
  the task).
- A local REST API bridge
  (`src/app/features/tasks/local-rest-api-feature-bridge.service.ts`) and
  URL-scheme actions (`docs/wiki/3.05-Web-App-vs-Desktop.md`).

## 11. Strengths worth borrowing

1. **Plan date and deadline are separate fields** (`dueDay`/`dueWithTime`
   against `deadlineDay`/`deadlineWithTime`). A study block has a "when I
   work on it" and an exam has a "due"; conflating them was a long-running
   complaint
   ([#405](https://github.com/super-productivity/super-productivity/issues/405),
   46 comments;
   [#7069](https://github.com/super-productivity/super-productivity/issues/7069),
   21 comments). Omakase's tasks already carry both `scheduled_date` and
   `due_date` in the API.
2. **Time is stored per day** (`timeSpentOnDay`). Per-day totals need no
   range scan, and the worklog and metrics read it directly.
3. **Future repeats are projections, not stored instances**
   (`planner-repeat-projection/`), with `deletedInstanceDates` as an
   exception list. Omakase's class occurrences are already computed, not
   stored (90-day window); the exception list is the missing half, since
   cancelled class occurrences are not built.
4. **Repeat options that answer real pain:** `waitForCompletion` (no
   pile-up), `skipOverdue`, `repeatFromCompletionDate`, and the Nth-weekday
   and last-day monthly anchors. Omakase has no recurring tasks; they are
   promised only (docs/IDEA.md §2).
5. **Capacity per day:** the planner's `timeEstimate` against
   `availableHours` and `progressPercentage`, and the schedule's over-budget
   split, make over-planning visible. Omakase stores daily work and study
   goal hours on the profile; a workload check is promised only
   (docs/IDEA.md §6).
6. **Finish-day is a function of a given day, not of "today"**
   (`dayStr` in `before-finish-day.model.ts`). This is the same rule as
   Omakase's invariant 2.
7. **The evaluation is small:** `impactOfWork` 1-4, `energyCheckin` 1-3, a
   reflection note. It is cheap to fill in and gives a trend line.
   Omakase's API review (rating 1-5, win of the day, shutdown flag) is of
   the same size; the Mac review screen is planned (docs/ROADMAP.md M3).
8. **Idempotent upload keyed by a client operation id** on SuperSync, the
   same idea as Omakase's `Idempotency-Key`.

## 12. Weaknesses to avoid

1. **Repeats are created on the client, per device.** An instance is made by
   whichever client sees the date change (`task-due.effects.ts`), so the
   code waits for sync to avoid duplicate instances across clients, and a
   missed trigger
   ([#6230](https://github.com/super-productivity/super-productivity/issues/6230))
   leaves the day without its repeats.
2. **The schedule is derived, not declared.** A task has one `dueWithTime`
   and the timeline reflows from estimates. Users find it hard to follow
   ([#9925](https://github.com/super-productivity/super-productivity/issues/9925)
   "schedule (make it understandable)",
   [#9991](https://github.com/super-productivity/super-productivity/issues/9991)),
   and a task cannot have two blocks.
3. **The end-of-day archive is a multi-entity bulk operation** that has
   stalled sync
   ([#9537](https://github.com/super-productivity/super-productivity/issues/9537),
   [#9768](https://github.com/super-productivity/super-productivity/issues/9768),
   [#10102](https://github.com/super-productivity/super-productivity/issues/10102)).
4. **Silent-loss paths are acknowledged in the docs**: the conflict journal
   is disabled, and a stopped sync is resolved by replacing a whole dataset
   (§8).
5. **Pomodoro was reworked into an overlay-heavy focus mode** and lost
   users who liked the old one
   ([#5737](https://github.com/super-productivity/super-productivity/issues/5737),
   49 comments: "If I stop the tracking for the task, the pomodoro timer
   continues").
6. **One web codebase in WebViews** brings mobile keyboard, scroll and
   hit-area bugs, and iOS performance problems
   ([#9779](https://github.com/super-productivity/super-productivity/issues/9779),
   13 comments).

## 13. Bottom line (for a work+study planner)

Super Productivity is the most complete open-source reference for the
*work* side: tasks, subtasks, repeats, a computed timeline, per-day time
tracking, focus modes, a finish-day ritual and a worklog. It is free, with
no paid tier published.

It has no study model: no semester, discipline, class timetable or study
block. Its schedule is auto-flow from estimates, not blocks the user
places. Its sync is a serverless-first operation log (vector clocks and
last-write-wins) because it has to work over WebDAV and Dropbox, and most
of its recent tracker pain comes from that choice and from the WebView
shell (see [`issues-super-productivity.md`](issues-super-productivity.md)).

Omakase's API already has what Super Productivity lacks for this user:
semesters, disciplines, study blocks and a weekly class timetable,
explicit time blocks, and a server that owns every row, with the Mac
client's outbox replaying writes under idempotency keys. The Mac client
itself has only sign-in and a Today checklist today. The field-level ideas
worth weighing are plan date against deadline, per-day time, repeat
projections with an exception list, capacity per day and a day-scoped
finish-day. The derived timeline and client-side creation of repeat
instances are the parts not to copy.

## 14. Sources

- https://github.com/super-productivity/super-productivity (code at
  `a76c1bccea42f091ed42b1c48d7e78686247caa4`; every backticked path above)
- https://super-productivity.com/
- https://super-productivity.com/pricing/
- https://github.com/super-productivity/super-productivity/issues/405
- https://github.com/super-productivity/super-productivity/issues/2657
- https://github.com/super-productivity/super-productivity/issues/5643
- https://github.com/super-productivity/super-productivity/issues/5737
- https://github.com/super-productivity/super-productivity/issues/6040
- https://github.com/super-productivity/super-productivity/issues/6230
- https://github.com/super-productivity/super-productivity/issues/7069
- https://github.com/super-productivity/super-productivity/issues/7726
- https://github.com/super-productivity/super-productivity/issues/7892
- https://github.com/super-productivity/super-productivity/issues/7931
- https://github.com/super-productivity/super-productivity/issues/8243
- https://github.com/super-productivity/super-productivity/issues/9537
- https://github.com/super-productivity/super-productivity/issues/9768
- https://github.com/super-productivity/super-productivity/issues/9779
- https://github.com/super-productivity/super-productivity/issues/9925
- https://github.com/super-productivity/super-productivity/issues/9991
- https://github.com/super-productivity/super-productivity/issues/10102

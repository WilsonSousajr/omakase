# M3.6 Reminders: design

**Status:** decided 2026-09-26 under the milestone-checkpoint rule. The user
reviews M3 as a whole when this slice lands.
**Milestone:** M3, "The daily loop". **Issue:** #127, from M7 R5.
**Parent spec:** `2026-09-25-macos-client-design.md` L198-199, which asks
for notifications on pomodoro transitions and a configurable heads-up before
the next block.

## The question #127 leaves open

#127 asks for "a reminder as data on a task, a study block or a time block:
an offset or absolute time, and whether it has fired or been dismissed",
served by the API and scheduled by each client.

Built literally, that is a new model with a reference to exactly one of
three owners, spread across two apps that may not import each other. It
would need a new create endpoint the outbox replays (invariant 9) and a
fired/dismissed state synced between clients. Today there is one client,
and two reminders anyone asks for.

## Decision: the two reminders the loop needs, defined on the server

1. **A heads-up before every block.**
   - This is the parent spec's "configurable heads-up before the next
     block", and IDEA §19.4's "upcoming block reminder: X minutes before".
   - It is a single user preference, not data on each block: every block
     gets the same heads-up.
   - `UserProfile.block_reminder_minutes`, 1-120 or null for off. The
     default is 5.
2. **"Remind me" on a task at a time**, what TickTick's and Things' users
   mean by a reminder.
   - `Task.remind_at` is a nullable, timezone-aware datetime. The client
     sends it with its UTC offset.
3. **A shutdown reminder at a time of day.** This is IDEA §19.4, and it is
   what gets the review taken.
   - `UserProfile.shutdown_reminder_time` is a nullable time of day in the
     user's local time. The default is null, which means off.

**Why this satisfies #127:**

- The reminders are defined once, on the server, and each client only
  schedules them. iOS reads the same three fields.
- Everything is additive on existing endpoints (`auth/profile/` and
  `tasks/`), so there is no new create for the outbox. On the Mac,
  `remind_at` is an ordinary `task.patch`.

**What is left out, and why:**

- **"Fired" is derivable:** `remind_at` is in the past.
- **"Dismissed" matters only when a second device would show the same
  reminder again.** It comes with iOS, as a `remind_dismissed_at`, when
  there is a second client to disagree.
- **A reminder on a study block** is its time block's heads-up. Study blocks
  have no time of day of their own.

## 1. Backend (PR I, #127)

- `UserProfile.block_reminder_minutes`: `PositiveSmallIntegerField`, null
  allowed, default 5. The serializer rejects a value outside 1-120 with the
  offending value and the range (invariant 3), and a database check
  constraint is the safety net.
- `UserProfile.shutdown_reminder_time`: `TimeField`, null allowed.
- `Task.remind_at`: `DateTimeField`, null allowed.
  - It is read and written through `tasks/`.
  - It is also returned by `tasks/today/` and `tasks/carried-over/`
    (`TaskDayListSerializer`).
- Migrations, tests first, and regenerated contract fixtures for the
  profile and the task list shapes.
- `CHANGELOG.md` names the three fields (invariant 8), and
  `docs/ARCHITECTURE.md` describes them.

## 2. Mac (PR J, new issue)

- **DTOs and records:**
  - `ProfileDTO` and `ProfileRecord` gain `blockReminderMinutes` and
    `shutdownReminderTime`.
  - `TaskDTO` and `TaskRecord` gain `remindAt`.
  - `TaskWrites.setReminder(_:at:)` queues a `task.patch` with
    `remind_at`, or an explicit null to clear it.
- **`ReminderPlanner`** is pure, in Features.
  - It takes the day's time blocks (with task and study titles), the
    profile, the tasks with `remindAt`, the review's `isShutdown`, `now`
    and a calendar.
  - It returns `[PlannedReminder(id, fireDate, title, body)]`, only in the
    future and at most 64, which is the system's pending limit.
  - Every id starts with `omakase.reminder.`.
  - After shutdown, block heads-ups and the shutdown reminder are dropped.
- **`ReminderScheduler`** lives in the app target. After each day refresh
  and after each write, it replaces the pending `omakase.reminder.*`
  requests with the plan. Idempotent ids mean a re-plan never duplicates.
  It reuses the notification authorization M3.3 already asks for.
- **Focus task panel:** a "Remind me" menu offers:
  - In 1 hour
  - This evening (18:00)
  - Tomorrow morning (09:00)
  - Pick a time…
  - Clear

  The task row shows a bell mark when a reminder is set.
- **Preferences UI** is M5's Settings. Until then, the defaults apply:
  5 minutes before blocks, and no shutdown reminder.

## Verification

- **Backend:**
  - Two users.
  - Validation at 0, at 121, and null.
  - `remind_at` round-trips with a non-UTC offset.
  - The fixtures are regenerated.
- **Mac:**
  - `ReminderPlanner` cases:
    - A block starting in 3 minutes with a 5-minute heads-up gets none,
      because its fire date has passed.
    - Blocks later today.
    - A task `remindAt` in the past or the future.
    - The shutdown time.
    - After shutdown.
    - More than 64 reminders.
  - The `setReminder` write carries an explicit null.
- **Real app:**
  1. Set "Remind me in 1 hour" on a task, then move `remind_at` to now+1
     minute with curl.
  2. After the next refresh, a notification arrives.
  3. Create a time block starting in 7 minutes. The heads-up arrives at
     minus 5.

## PRs

| # | Issue | Contents |
|---|---|---|
| I | #127 | Backend: the three fields, validation, fixtures, CHANGELOG, ARCHITECTURE, this spec |
| J | #187 | Mac: DTOs and records, `setReminder`, `ReminderPlanner`, `ReminderScheduler`, the Remind me menu, `SMOKE.md` M3.6, ROADMAP (M3 built) |

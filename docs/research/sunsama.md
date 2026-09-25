# Sunsama - deep dive

> Captured **2026-09-25**, against Omakase's `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **What was read.** help.sunsama.com (a Docusaurus user manual, fetched
> page by page, with the full article index), sunsama.com, its pricing and
> desktop pages, the 2025 roadmap blog post, roadmap.sunsama.com (the Canny
> board and changelog), and the iOS App Store listing.
>
> **Coverage limits.** No help article describes the analytics screen. The
> student discount amount is not stated anywhere read. The Google Play
> listing was not opened, and the Mac App Store was not checked. Reddit
> could not be reached (the fetch tool blocks reddit.com), so there is no
> Reddit user voice.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## 1. Purpose and target user

The headline is "Start Calm. Stay Focused. End Confident." and "Make
work-life balance a reality", with promises to "end the day on time,
feeling accomplished" and "see tasks and meetings together in one clear
plan" (marketing page, [sunsama.com](https://www.sunsama.com/)). The same
page claims a "Community of 300k+ people" and "Best Scheduling Tool" from
NYT Wirecutter (vendor-self-reported).

The 2025 roadmap post calls it "a task manager for modern professionals",
for people handling the "stress, pressure, and ambition of work"
([roadmap post](https://www.sunsama.com/blog/sunsama-2025-task-manager-roadmap)).

The target user is the knowledge worker with meetings. The help centre
frames everything as work versus personal and has nothing for students
(§6).

## 2. Data model

- **Task:** planned time, actual time, subtasks, notes, comments, channel,
  priority, recurrence. Incomplete tasks **roll over at midnight** by
  default, and tasks that roll over several days in a row are auto-archived
  ([rollover and recurring](https://help.sunsama.com/docs/getting-started/basics/task-rollover-and-recurring-tasks-the-basics)).
- **Channels** categorise tasks, events and objectives ("where you are
  spending your time"). **Contexts** group channels (for example #work,
  #personal). A context flagged "Personal" does **not count toward
  workload**. The guidance is 5-7 fairly high-level channels per context.
  A channel can be linked to a calendar ("Import channel" and "Timebox
  channel"), so work sessions land on the work calendar and personal ones
  on the personal calendar
  ([channels and contexts](https://help.sunsama.com/docs/usage-guides/channels-and-contexts)).
- **Subtasks** are made by merging: Alt/Option-drag a task onto another.
  A subtask keeps its notes, planned time and integration link, and can be
  turned back into a task. **Calendar-event tasks cannot have subtasks**
  ([merge tasks](https://help.sunsama.com/docs/usage-guides/tasks/merge-tasks)).
- **Weekly objectives** look like tasks, can span several days, and tasks
  are "aligned" to them (R key). A task can become an objective, and
  dragging an objective into a day creates an aligned task. Objectives are
  **weekly only**
  ([weekly objectives](https://help.sunsama.com/docs/usage-guides/weekly-objectives));
  monthly, quarterly and yearly are among the top open requests
  ([`issues-sunsama.md`](issues-sunsama.md), E).
- **Backlog:** every task sits in a **time bucket** (Next week or two,
  Next month, Next quarter, Next year, Someday (the default), Never).
  **Folders** exist only in the backlog: scheduling a task onto a day
  removes its folder. There is a voice "Braindump" with Sunny, the AI
  assistant. "The backlog is not a replacement for a project management
  tool." ([backlog](https://help.sunsama.com/docs/usage-guides/backlog))
- **No project entity.** The docs have channels, contexts, objectives and
  backlog folders only, and the 2025 roadmap post does not list projects
  ([roadmap post](https://www.sunsama.com/blog/sunsama-2025-task-manager-roadmap)).
- **No study entities.** The help-centre index has no semester, course,
  class schedule or exam ([index](https://help.sunsama.com/)).

## 3. Planning surface

- A **working session** is a calendar event created by timeboxing a task;
  planned time sets its duration
  ([concepts](https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-concepts-and-principles)).
  The alternative "playlist" method is an ordered list with estimates and
  no timeboxing (same page).
- Three ways to timebox: drag onto the calendar, press **X** to
  auto-schedule, or add sessions on the same or other days from the
  working-session popout. **Moving a task to another day removes its
  working session**, while moving the session moves the task. One task can
  have sessions on several days, and deleting one instance deletes the
  whole task
  ([how to timebox](https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-how-to-timebox)).
- **Auto-schedule** respects "Schedules" (working hours, plus per-channel
  schedules). It avoids busy events, ignores declined and free events, and
  **splits tasks longer than 1 h** around events (Shift+X prevents the
  split). When the day is overcommitted it offers Schedule anyway, another
  day, or Defer. It considers only events in view
  ([auto-scheduling](https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-auto-scheduling)).
- **Auto-reschedule** has two triggers: it deconflicts overlapping working
  sessions, and it shifts contiguous later sessions forward when a task
  finishes early. Meetings are never moved, and a task that no longer fits
  is unscheduled from the calendar but stays in the task list. Shift-drag
  prevents it and Cmd+Z undoes it
  ([auto-rescheduling](https://help.sunsama.com/docs/usage-guides/timeboxing/auto-rescheduling)).
- A **built-in private calendar** has no sharing, no invites and **no
  recurring events**. Google, Outlook and iCloud can be connected; iCloud
  needs an app-specific password
  ([calendar](https://help.sunsama.com/docs/integrations/calendar)).

## 4. Daily ritual

**Daily planning.** Press P, or it opens at the time set under Settings >
Rituals ([daily planning](https://help.sunsama.com/docs/usage-guides/daily-planning)).

1. *Reflect on yesterday.* Shown only if yesterday's shutdown was skipped:
   mark tasks done or edit past work.
2. *Add tasks* from calendar events, integrations, the backlog or weekly
   objectives, or create new ones.
3. *Check predicted workload.* Sunsama sums the planned time of **work**
   tasks and compares it with a **workload threshold**, warning when it is
   exceeded. A timeline shows the estimated finish time against the
   preferred shutdown time. Defer (D) or backlog (Z). The docs tell new
   users to target about 5.5 h of an 8 h day.
4. *Finalize.* Order the tasks, optionally timebox them, and set the
   shutdown time (optionally as a calendar event).
5. *Share.* Note obstacles, optionally post to Slack or Teams, then "Get
   Started".

Planning set after 3 PM plans **tomorrow** ("evening mode"), and planning
can be re-entered at any time (same page). Each day column has a
**workload counter**: total remaining, work remaining, or actual against
planned. It turns yellow near the threshold and red over it, and filtering
by channel changes the totals
([planned and actual](https://help.sunsama.com/docs/usage-guides/tasks/planned-and-actual-times)).
The threshold can be set per day, and only "work" contexts count
([user settings](https://help.sunsama.com/docs/settings/user-settings)).

**Daily shutdown.** O key, or automatic
([daily highlights](https://help.sunsama.com/docs/usage-guides/daily-highlights)).

1. The tasks worked on today, with a time breakdown.
2. *Highlights.* Some are auto-selected by a ranking algorithm, with AI
   summaries; "other activities" (tasks, emails, integration items) can be
   pulled in.
3. *Personal reflection:* what went well, concerns, obstacles, an emoji,
   optional prompt templates.
4. *Publish* to a "daily highlights journal", optionally shared via email,
   Slack or Teams.

A changelog entry says a shutdown-time notification prompts the ritual; the
page shows no date
([changelog](https://roadmap.sunsama.com/changelog/daily-shutdown)).

**Weekly planning**
([weekly planning](https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-planning)):
set objectives, carrying last week's forward ("Continue N objectives") and
adding new ones, then journal a reflection. Review and planning can be one
flow. The docs advise objectives, not tasks, for the week.

**Weekly review**
([weekly review](https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-review)):
time on objectives against other work, marking objectives complete; the
body of work with a time breakdown by day (weekends optional); a journal of
wins, distractions and lessons, shareable to Slack or Teams.

## 5. Focus

- **Focus mode** (F) is a single-task full screen with the timer, subtasks
  and notes. The calendar shows on hover, and the view **auto-advances to
  the next task** on completion. It has a "Pomodoro" tab
  ([focus mode](https://help.sunsama.com/docs/usage-guides/focus-mode)).
- The **task timer** (Spacebar) records actual time. Starting it enters
  focus mode by default, and subtasks have their own timers
  ([planned and actual](https://help.sunsama.com/docs/usage-guides/tasks/planned-and-actual-times)).
- The **Focus Bar** is a floating desktop bar with play, pause and
  complete, and needs the desktop app running. Cmd+Shift+Space starts or
  stops the timer globally. Sounds can play 10, 5 or 0 min before planned
  time is reached
  ([focus bar](https://help.sunsama.com/docs/usage-guides/focus-bar)).
- **Breaks and pomodoro:** break reminders after a configurable work
  duration, with take, snooze 5 min, or skip. The pomodoro view counts down
  to the next break; the default view counts up. **Desktop app only**
  ([breaks](https://help.sunsama.com/docs/usage-guides/breaks)). A setting
  chooses "between the default task timer or pomodoro timer when entering
  focus mode"
  ([user settings](https://help.sunsama.com/docs/settings/user-settings)).
- "Pomodoro timer" is marked complete on the board with 1,067 votes
  ([board](https://roadmap.sunsama.com/improvements/p/pomodoro-timer)).
- **Not found** in the docs: a rating for a focus session, or pomodoro
  counts per task. Sunsama's pomodoro is a break cadence on top of a time
  tracker.

## 6. Study features

- **None found.** The help-centre index has no articles on classes,
  courses, semesters, timetables, exams or study
  ([index](https://help.sunsama.com/)). The one student-specific item is
  billing (§9).
- Students did ask to pay less: "Student Discount" has 859 votes and is
  marked complete
  ([board](https://roadmap.sunsama.com/improvements/p/student-discount)).
- A student would have to model courses as channels in a "school" context
  and classes as calendar events imported as tasks. That is an inference
  from the channel and calendar docs, not a documented workflow.

## 7. Analytics

- The entry point is the main dropdown ("settings, analytics, and other
  account features")
  ([navigation](https://help.sunsama.com/docs/usage-guides/workspace-navigation)).
  No help article describes the analytics screen, so its contents are not
  verified.
- The time insight lives in the rituals: the shutdown's time breakdown
  ([daily highlights](https://help.sunsama.com/docs/usage-guides/daily-highlights)),
  the weekly review's time on objectives and per-day breakdown
  ([weekly review](https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-review)),
  and time by channel in the ritual flows
  ([channels and contexts](https://help.sunsama.com/docs/usage-guides/channels-and-contexts)).
- Users on the board say "Currently one can see data only by week" and ask
  for custom ranges, actual against estimate, and a full export. The post
  shows 685 votes; the page labels it "Merged", while the API says "open"
  ([board](https://roadmap.sunsama.com/improvements/p/improved-analytics-and-data-insights)).
- Data export exists: Settings > Account Management > Export my data
  ([FAQ](https://help.sunsama.com/docs/faq/faq)).
- Sunny, the AI assistant, can "summarize your completed work over any
  period" ([Sunny](https://help.sunsama.com/docs/usage-guides/sunny)).

## 8. Platforms, native or not, offline

- **Desktop:** macOS, Windows and Linux downloads
  ([desktop](https://www.sunsama.com/desktop)). The desktop app **is
  Electron**: "The desktop app uses Electron"
  ([FAQ](https://help.sunsama.com/docs/faq/faq)), and the changelog lists
  "Desktop app 3.4.12 … Electron 44 update" on 2026-09-23
  ([changelog](https://roadmap.sunsama.com/changelog)).
- **iOS, iPadOS, visionOS:** the listing says "Companion app to the desktop
  app", 4.5★ from 504 ratings, iOS 16.4+
  ([App Store](https://apps.apple.com/us/app/sunsama/id1475755747)).
  Android is linked via sunsama.com/mobile
  ([FAQ](https://help.sunsama.com/docs/faq/faq)).
- **Offline: not supported.** "Offline mode for desktop app" is **open**
  with 230 votes, posted 2020-06-11. Comments include "the whole app is
  failing to load" and "just a basically functional see list and add a
  local task until online again"
  ([board](https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app)).
  The latest desktop changelog mentions "improved network reconnection"
  ([changelog](https://roadmap.sunsama.com/changelog)).
- The focus bar, break reminders and pomodoro prompts **need the desktop
  app running** ([focus bar](https://help.sunsama.com/docs/usage-guides/focus-bar),
  [breaks](https://help.sunsama.com/docs/usage-guides/breaks)).

## 9. Pricing and student plans

- **Pro: $22 a month billed monthly, $17 a month billed yearly** ($204 a
  year). Enterprise is custom (SSO, SAML, SCIM, audit logs). The pricing
  page also says "$25/month per person ($20/month for yearly plans)" for
  team members, which conflicts with the help centre's "$22/user/month …
  $17/user/month"; both are recorded as found
  ([pricing](https://www.sunsama.com/pricing),
  [billing](https://help.sunsama.com/docs/billing/overview)).
- **Trial: 14 days, no card**, the full product. Access ends when it
  expires; there is **no free tier**
  ([billing](https://help.sunsama.com/docs/billing/overview)).
- **Student discount:** for an account on an enrolled college student's
  email (.edu), requested by email, lasting until graduation or 4 years,
  whichever is first. The amount is **not stated** (same page).
- Non-profit pricing on request; no regional discounts; workspace data
  deleted 30 days after cancellation (same page).

## 10. Integrations

- The help centre lists Calendar (Google, Outlook, iCloud), Gmail, Outlook
  email, Asana, ClickUp, GitHub, Jira, Linear, MCP, Microsoft Planner,
  Teams, To Do, Monday, Notion, Todoist, Trello, Slack, Zapier, Toggl
  Track, Apple Reminders and Google Tasks
  ([index](https://help.sunsama.com/)).
- **Todoist** is an import-on-demand panel, not a mirror. Due date and
  completion can each sync **both ways** by toggle, and only one Todoist
  account is allowed
  ([Todoist](https://help.sunsama.com/docs/integrations/todoist)).
- An **MCP server** at https://api.sunsama.com/mcp uses OAuth and has a
  ChatGPT plugin ([MCP](https://help.sunsama.com/docs/integrations/mcp)).
  A public REST API is an **open** request with 887 votes
  ([board](https://roadmap.sunsama.com/improvements/p/sunsama-api)).
- A CalDAV integration beta opened to all on 2026-09-23
  ([changelog](https://roadmap.sunsama.com/changelog)).

## 11. Strengths worth borrowing

1. **The workload threshold as a gate inside planning.** Planned work is
   shown against a daily capacity, with a projected finish time against
   the shutdown time and one-key defer or backlog
   ([daily planning](https://help.sunsama.com/docs/usage-guides/daily-planning),
   [planned and actual](https://help.sunsama.com/docs/usage-guides/tasks/planned-and-actual-times)).
   Omakase's API stores daily work and study goal hours on the profile and
   `estimated_minutes` on tasks and study blocks; a workload check is
   promised only (docs/IDEA.md §6).
2. **The personal context excluded from workload**
   ([channels and contexts](https://help.sunsama.com/docs/usage-guides/channels-and-contexts)).
   The question it raises for Omakase is whether study counts toward the
   same capacity or has its own budget; the profile already keeps the two
   goals apart.
3. **The shutdown closes the loop.** Skipping it makes the next planning
   session open with "reflect on yesterday"
   ([daily planning](https://help.sunsama.com/docs/usage-guides/daily-planning)).
   Omakase's daily review exists in the API (`stats/reviews/`); the review
   and shutdown screens are planned (docs/ROADMAP.md M3).
4. **Backlog time buckets** (Next week or two to Never) instead of fake due
   dates ([backlog](https://help.sunsama.com/docs/usage-guides/backlog)).
5. **Auto-reschedule on early finish that never moves meetings**
   ([auto-rescheduling](https://help.sunsama.com/docs/usage-guides/timeboxing/auto-rescheduling)).
   The Omakase analogue is class occurrences as fixed blocks.
6. **A floating focus bar and a global timer shortcut**
   ([focus bar](https://help.sunsama.com/docs/usage-guides/focus-bar)).
   Omakase plans a menu-bar timer (docs/ROADMAP.md M3).
7. **"Continue N objectives" in weekly planning**
   ([weekly planning](https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-planning)).

## 12. Weaknesses to avoid

1. **An online-only Electron app.** No offline mode since at least the
   2020 request (230 votes, open)
   ([board](https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app)).
2. **Focus and break features depend on a running desktop app**, and
   mobile is a "companion"
   ([App Store](https://apps.apple.com/us/app/sunsama/id1475755747)).
3. **Objectives are weekly only**, with no month, quarter or year; these
   are the top open requests (`issues-sunsama.md`, E).
4. **Subtasks are second-class:** created by merge, and none on event tasks
   ([merge tasks](https://help.sunsama.com/docs/usage-guides/tasks/merge-tasks);
   "Subtasks should be full tasks", 905 votes,
   [board](https://roadmap.sunsama.com/improvements/p/subtasks-should-be-full-tasks)).
5. **Scheduling is lost as a side effect.** Moving a task to another day
   drops its working session, and a deconflict that runs out of room
   takes tasks off the calendar; the page does not say the user is told
   ([how to timebox](https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-how-to-timebox),
   [auto-rescheduling](https://help.sunsama.com/docs/usage-guides/timeboxing/auto-rescheduling)).
6. **Rollover is fixed at midnight.** "Option to change rollover time …
   after midnight" (152 votes) is **closed**; the reason was not read
   ([board](https://roadmap.sunsama.com/improvements/p/option-to-change-rollover-time-end-of-day-time-to-after-midnight)).
   A student working late does not end the day at midnight. Omakase's
   "today" is the client's calendar date (invariant 2 in `AGENTS.md`), so
   the same question applies to it.
7. **No project entity**; folders exist only in the backlog
   ([backlog](https://help.sunsama.com/docs/usage-guides/backlog)).
8. **Price:** $17-22 a month and no free tier
   ([billing](https://help.sunsama.com/docs/billing/overview)).

## 13. Bottom line (for a work+study planner)

Sunsama is the reference implementation of the **ritual**: plan against
capacity, timebox around fixed events, focus, shut down, then plan and
review the week. It is built for a meeting-heavy professional. It has no
study model: no semesters, courses or timetable, so a student fakes
courses with channels and classes with calendar events. It is online-only
Electron, keeps focus and breaks on the desktop, and caps goals at one
week.

Omakase's design differs on each of those axes, but mostly on paper today.
The study hierarchy, the timetable, timeboxing, pomodoro sessions and the
daily review exist in the API only. The shipped Mac client has sign-in and
an offline-capable Today checklist. The ritual itself - focus, the review,
the shutdown - is planned (docs/ROADMAP.md M3), and the morning plan with a
workload check is promised only (docs/IDEA.md §6). The workload check is
Sunsama's core mechanic, and nothing in Omakase's clients does it today.

## 14. Sources

- https://www.sunsama.com/ (marketing page)
- https://www.sunsama.com/blog/sunsama-2025-task-manager-roadmap
- https://www.sunsama.com/pricing
- https://www.sunsama.com/desktop
- https://help.sunsama.com/
- https://help.sunsama.com/docs/getting-started/basics/task-rollover-and-recurring-tasks-the-basics
- https://help.sunsama.com/docs/usage-guides/channels-and-contexts
- https://help.sunsama.com/docs/usage-guides/tasks/merge-tasks
- https://help.sunsama.com/docs/usage-guides/weekly-objectives
- https://help.sunsama.com/docs/usage-guides/backlog
- https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-concepts-and-principles
- https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-how-to-timebox
- https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-auto-scheduling
- https://help.sunsama.com/docs/usage-guides/timeboxing/auto-rescheduling
- https://help.sunsama.com/docs/integrations/calendar
- https://help.sunsama.com/docs/usage-guides/daily-planning
- https://help.sunsama.com/docs/usage-guides/tasks/planned-and-actual-times
- https://help.sunsama.com/docs/settings/user-settings
- https://help.sunsama.com/docs/usage-guides/daily-highlights
- https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-planning
- https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-review
- https://help.sunsama.com/docs/usage-guides/focus-mode
- https://help.sunsama.com/docs/usage-guides/focus-bar
- https://help.sunsama.com/docs/usage-guides/breaks
- https://help.sunsama.com/docs/usage-guides/workspace-navigation
- https://help.sunsama.com/docs/usage-guides/sunny
- https://help.sunsama.com/docs/faq/faq
- https://help.sunsama.com/docs/billing/overview
- https://help.sunsama.com/docs/integrations/todoist
- https://help.sunsama.com/docs/integrations/mcp
- https://roadmap.sunsama.com/changelog
- https://roadmap.sunsama.com/changelog/daily-shutdown
- https://roadmap.sunsama.com/improvements/p/pomodoro-timer
- https://roadmap.sunsama.com/improvements/p/student-discount
- https://roadmap.sunsama.com/improvements/p/improved-analytics-and-data-insights
- https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app
- https://roadmap.sunsama.com/improvements/p/sunsama-api
- https://roadmap.sunsama.com/improvements/p/subtasks-should-be-full-tasks
- https://roadmap.sunsama.com/improvements/p/option-to-change-rollover-time-end-of-day-time-to-after-midnight
- https://apps.apple.com/us/app/sunsama/id1475755747

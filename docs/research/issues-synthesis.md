# What users of five planners keep asking for - synthesis

> Captured **2026-09-25**, against `develop` at `51abb80`. Built only from
> the five audited mining documents: `issues-ticktick.md` (TT),
> `issues-sunsama.md` (SUN), `issues-super-productivity.md` (SP),
> `issues-mystudylife.md` (MSL, which covers MyStudyLife, Power Planner and
> Shovel) and `issues-motion.md` (MOT, which covers Motion and Reclaim).
> Every piece of evidence below links to the venue it came from; the
> sampling method for each venue is in its own document's header.
>
> **The venues are not alike, and that limits what a count means.** Sunsama
> and Reclaim have public voting boards; Super Productivity and Power
> Planner have GitHub trackers; TickTick, MyStudyLife, Shovel and Motion
> have no public board, so their evidence is App Store reviews read through
> Apple's public review feed - user voice, not a description of how the
> product works. A theme missing from a venue is not evidence that its
> users do not want it.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## Why a synthesis

A need that shows up on one product's board says something about that
product. The same need showing up independently on five products' boards,
among users who never read each other's forums, says something about the
job all five are hired for. That is the evidence this file exists to find,
and it is stronger than anything `docs/IDEA.md` asserts on its own.

Each finding is classed the way the per-venue documents class it:

- **(a)** Omakase's design already answers it. Where it lives is named:
  shipped in the API, planned in a ROADMAP milestone, or promised only in
  IDEA.md.
- **(b)** Structural to the competitor's architecture and not possible in
  Omakase's (a server of record, a native client with an idempotent outbox,
  the client's date on every "today").
- **(c)** Omakase also lacks it.

The audit of the mining documents moved several rows from (b) to (c).
Most of what competitors' users complain about, Omakase does not avoid by
construction. It simply has not built that part yet.

## 1. Recurring tasks that work - five venues of five

| Where | What |
|---|---|
| TT | A rule that future repeats "cannot" be edited until the current one is completed ([help](https://help.ticktick.com/articles/7055792921664028672)); repeat bugs recur in reviews |
| SUN | "Repeat every N days", 204 votes ([board](https://roadmap.sunsama.com/improvements/p/allow-recurring-tasks-to-be-repeated-by-number-of-days)) |
| SP | [#427](https://github.com/super-productivity/super-productivity/issues/427), 50 comments; [#6230](https://github.com/super-productivity/super-productivity/issues/6230), repeats missed when the day-change trigger is missed |
| MSL | Copying and bulk-editing repeats, in MyStudyLife reviews |
| MOT | "doesn't support recurring task creation" (Motion review); Reclaim lists Recurring Tasks in its backlog ([board](https://updates.reclaim.ai/board)) |

**Class (c).** Omakase has no recurrence. The only thing that repeats is a
class, and class occurrences are computed per request
(`study/class-occurrences/`), never stored. Recurring tasks are promised
only (IDEA §2). The Super Productivity evidence adds a design warning:
its repeats are created by each client and duplicate when two devices
both create them ([`issues-super-productivity.md`](issues-super-productivity.md)).
Nothing in Omakase's architecture prevents the same mistake; the computed
class occurrences show a pattern that would.

## 2. A phone app at parity with the desktop - five venues of five

| Where | What |
|---|---|
| TT | The help centre's own list of features missing on Mac, Windows and web ([help](https://help.ticktick.com/articles/7055782085826445312)) |
| SUN | "Unified design on mobile", 256 votes ([board](https://roadmap.sunsama.com/mobile-apps/p/unified-design-on-mobile-make-mobile-app-similar-to-desktop)) |
| SP | [#9779](https://github.com/super-productivity/super-productivity/issues/9779), iOS performance in the WebView build |
| MSL | Shovel's phone app described as abandoned in reviews from 2022 to 2026 |
| MOT | Motion's own help page calls mobile "quite a bit behind" ([help](https://www.usemotion.com/help/getting-started/mobile-app/reference-mobile-app.md)) |

**Class (c).** Omakase has no phone app. iOS and Android are "Later" in
`docs/ROADMAP.md`. Only Super Productivity's cause, a WebView shell, is one
Omakase's native plan avoids by design.

## 3. Nothing lost, and usable when the network is not - five venues of five

| Where | What |
|---|---|
| TT | Reviewers report other devices not syncing "until I open the app" |
| SUN | "Offline mode for desktop app", 230 votes, open since 2020 ([board](https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app)) |
| SP | [#4544](https://github.com/super-productivity/super-productivity/issues/4544) "Lost data because of synchronisation"; last-write-wins replaces "the entire losing dataset" (`docs/wiki/3.06-User-Data.md` at `a76c1bc`) |
| MSL | "I lost my account and all my data" after the 2024 rewrite (review) |
| MOT | "Refreshing your desktop app ... can cause data loss" ([Motion help](https://www.usemotion.com/help/getting-started/display-options/motion-desktop-tabs.md)) |

**Class (a), partly - and only for one screen.** The Mac client's Today
checklist reads from a local SwiftData cache and writes through an ordered
outbox that replays with idempotency keys (M1, `apps/apple/Packages/OmakaseStore/`).
That is the property all five venues ask for, and today it covers exactly
one list and one action: ticking a task done. The offline indicator and
the failed-writes sheet are planned for M3. Against Super Productivity and
Sunsama the answer is (b): a server that serialises writes cannot lose a
dataset to a last-write-wins merge, and a native client is not an Electron
window that fails to load offline.

## 4. Reminders that fire and can be tuned - four venues

| Where | What |
|---|---|
| TT | Requests for a constant-reminder interval (review) |
| SUN | "Notifications on mobile app", 333 votes ([board](https://roadmap.sunsama.com/mobile-apps/p/notifications-on-mobile-app)) |
| MSL | MyStudyLife "not sending reminder notifications" (review, 2026-09-10); Power Planner "There are NO reminders" (review) |
| MOT | "cannot notify me to move on to the next task" (Motion review) |

**Class (c).** Notifications are planned for M3. There is no reminder
model in the API, so a reminder that must fire on a phone or on a Mac that
was asleep has nowhere to live yet.

## 5. A day that does not break at midnight or across timezones - four venues

| Where | What |
|---|---|
| TT | "Change day end time" on the unofficial board ([featurevote](https://ticktick.featurevote.app/)) |
| SUN | Rollover after midnight, 152 votes, closed ([board](https://roadmap.sunsama.com/improvements/p/option-to-change-rollover-time-end-of-day-time-to-after-midnight)) |
| SP | [#9650](https://github.com/super-productivity/super-productivity/issues/9650), [#9758](https://github.com/super-productivity/super-productivity/issues/9758), timezone bugs |
| MSL | Class times shifting after a clock change (MyStudyLife review, 2024-11-10); Power Planner [#90](https://github.com/powerplanner/powerplannerapps/issues/90) |

**Class (a) for "today", (c) for the rest.** Omakase never lets the
server decide what today is: the client sends `?date=` and the backend
rejects a request without one (AGENTS.md invariant 2, #65, #69). That
answers the "wrong day" half. Two halves are open: there is no day-start
setting for a user whose day ends at 2 a.m., and nothing tests class
occurrences across a daylight-saving change, which is exactly where
MyStudyLife and Power Planner users report drift.

## 6. Integrations, calendar import first - four venues

| Where | What |
|---|---|
| TT | Google Calendar events that cannot be edited (review) |
| SUN | CalDAV/iCloud, 219 votes ([board](https://roadmap.sunsama.com/integrations/p/caldavicloud-integration)); 18 of the top 50 open posts are integrations |
| SP | [#9830](https://github.com/super-productivity/super-productivity/issues/9830), two-way CalDAV |
| MSL | Power Planner [#131](https://github.com/powerplanner/powerplannerapps/issues/131), a to-do integration |

**Class (c).** A read-only Calendar.app overlay is planned for M5; Google
Calendar import and sync are promised only (IDEA §5, §19).

## 7. A price one person, or a student, can pay - four venues

| Where | What |
|---|---|
| TT | "calendar view is a paid add on" (review) |
| SUN | "Student Discount", 859 votes, marked complete ([board](https://roadmap.sunsama.com/improvements/p/student-discount)) |
| MSL | The free tier's five-task cap ([MSL+](https://mystudylife.com/msl-plus/)) and reviews about it |
| MOT | Individual pricing ([pricing](https://www.usemotion.com/pricing)) and charge complaints (reviews) |

**Not a product-design class.** Omakase has no pricing because it has no
distribution: the Mac spec rules out the App Store and TestFlight. Recorded
because it is the fourth most common need in the field, and because
`2026-landscape.md` §2 shows a student discount is already the norm.

## 8. Unfinished work carried into today - three venues

| Where | What |
|---|---|
| TT | "FIVE clicks" to move a task to today (review) |
| SUN | "Visually distinguish tasks that got rolled over", 609 votes, complete ([board](https://roadmap.sunsama.com/improvements/p/visually-distinguish-tasks-that-got-rolled-over-from-yesterday)) |
| MOT | "never losing sight of a task" (review) |

**Class (a), partly.** `tasks/carried-over/?date=` is shipped in the API;
complete and reschedule are planned for M3, and the rollover decision is
part of IDEA §8's review.

## 9. A focus timer tied to the task - three venues

| Where | What |
|---|---|
| SUN | "Pomodoro timer", 1,067 votes, complete ([board](https://roadmap.sunsama.com/improvements/p/pomodoro-timer)) |
| SP | [#5737](https://github.com/super-productivity/super-productivity/issues/5737), 49 comments, when simple Pomodoro was taken out of tracking |
| MSL | Power Planner [#61](https://github.com/powerplanner/powerplannerapps/issues/61), a timer, open since 2021 |

**Class (a), partly.** `pomodoro/sessions/` is shipped and links to a
task (not to a study block); the Mac timer is planned for M3.

## 10. Features not taken away by a rewrite - three venues

| Where | What |
|---|---|
| SP | [#5737](https://github.com/super-productivity/super-productivity/issues/5737), simple Pomodoro removed |
| MSL | "BRING BACK THE OLD VERSION!!!" after MyStudyLife v2 (review, 2024-09-04) |
| MOT | "removed the real AI Agenda" (Motion review, 2025-07-15) |

**Class (a), partly.** AGENTS.md invariant 8 makes the API a contract:
a changed shape changes its tests and is named in `CHANGELOG.md`. That
protects old clients from a new server. It does not stop a feature being
removed, which is what these users are complaining about.

## Needs found in two venues

| Need | Venues | Evidence | Class | Omakase today |
|---|---|---|---|---|
| A schedule the user places, that stays put | SP, MOT | SP [#9925](https://github.com/super-productivity/super-productivity/issues/9925); Motion's lock expires after 60 minutes ([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)) | (a) | `timeblocks/` are user-placed (API); calendar planned M4 |
| A plan date separate from the deadline | TT, SP | "add a do date", top item on the [featurevote](https://ticktick.featurevote.app/) board; SP [#5643](https://github.com/super-productivity/super-productivity/issues/5643) | (a) | `scheduled_date` and `due_date` on tasks and study blocks (API) |
| Grouping above the list | SUN, SP | Multiple backlogs, 272 ([board](https://roadmap.sunsama.com/improvements/p/create-multiple-backlogs-or-folderssections-in-backlog)); SP [#516](https://github.com/super-productivity/super-productivity/issues/516) | (a) | workspaces → projects → tasks (API); screens planned M5 |
| Subtasks as full tasks | SUN, SP | 905 votes ([board](https://roadmap.sunsama.com/improvements/p/subtasks-should-be-full-tasks)); SP [#2657](https://github.com/super-productivity/super-productivity/issues/2657), 45 comments | (c) | `Subtask` is a title, a done flag and an order, one level |
| Estimate against actual, projected finish | TT, SUN | "estimated finish time" ([featurevote](https://ticktick.featurevote.app/)); actual vs planned, 402 ([board](https://roadmap.sunsama.com/improvements/p/compare-actual-time-vs-planned-time)) | (c) | `estimated_minutes` shipped (API); accuracy promised IDEA §9 |
| Holidays, vacation, working days | SUN, MSL | Vacation mode, 584 ([board](https://roadmap.sunsama.com/improvements/p/vacation-holiday-ooo-sick-leave-mode)); holidays not suppressing classes (MSL review) | (c) | absent; cancel and holiday occurrences promised IDEA §3 |
| Bulk edit | SUN, MSL | 277 ([board](https://roadmap.sunsama.com/improvements/p/batchbulk-edit-select-multiple-tasks-to-move-or-edit)); Power Planner review | (c) | `reorder-bulk/` only |
| Undo after destructive actions | TT, MSL | Import-and-delete loss (TT review); undo complete (MSL review) | (c) | no undo or trash |
| Widgets and a watch | SUN, MSL | Apple Watch, 361 ([board](https://roadmap.sunsama.com/mobile-apps/p/apple-watch-app-widget-notifications)); Power Planner review | (c) | absent |
| Notes longer than a line | SUN, MSL | General notes, 344 ([board](https://roadmap.sunsama.com/improvements/p/general-notes-features)); Power Planner [#126](https://github.com/powerplanner/powerplannerapps/issues/126) | (a) on items, (c) as a feature | `notes` on tasks, study blocks and time blocks (API); notebooks promised IDEA §16 |

## What only one venue asked for, and what nobody asked for

Loud in one venue only: objectives longer than a week (Sunsama's top four
posts, about 3,970 votes between them), rotation timetables and grades
(MyStudyLife and Power Planner), a public API (Sunsama), and habits
(Sunsama, 654 voters). One venue is a signal about that product's users,
not about the field.

**No venue asked for a class timetable next to work.** TickTick's 500
sampled reviews, 88 of them from students, and Super Productivity's
tracker contain no such request. That does not show the need is absent:
people rarely ask a work planner for a feature they assume belongs to a
different category of app. It does mean Omakase's central premise is
supported by the empty square in `2026-landscape.md` §2 and by
MyStudyLife's paid "Activities", not by anyone's feature request.

## Bottom line

- The three strongest needs in the field, each asked for in all five
  venues, are recurring tasks, a phone app at parity, and not losing data.
  Omakase lacks the first two entirely and has the third for one list on
  one platform.
- Omakase's design answers five needs in principle: user-placed blocks, a
  plan date apart from the deadline, carried-over work, a task-linked focus
  timer, and a server-decided "today" that is never wrong. All of them are
  in the API, and none can be used in a client yet.
- The findings that are structural - the reason Omakase's architecture is
  a moat and not a preference - are narrower than the design documents
  assume: last-write-wins data loss, Electron and WebView shells, and the
  schedule churn of auto-placement.

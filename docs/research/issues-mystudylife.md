# MyStudyLife, Power Planner and Shovel - what their users keep asking for

> Captured **2026-09-25**, against `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered. This file mines **three** student planners
> together: MyStudyLife, Power Planner and Shovel.
>
> **Venues and sample.** MyStudyLife: the 150 most recent US App Store
> reviews from Apple's public review feed
> (`https://itunes.apple.com/us/rss/customerreviews/page=N/id=910639339/sortby=mostrecent/json`,
> pages 1-3, 2024-08-27 to 2026-09-10; reviews of 3 stars or fewer read in
> full), plus the reviews visible on its
> [Google Play listing](https://play.google.com/store/apps/details?id=com.virblue.mystudylife&hl=en_US).
> Power Planner: its 18 open GitHub issues
> ([issues](https://github.com/powerplanner/powerplannerapps/issues),
> repository at `c22d20c`) and 100 US App Store reviews (feed id
> 1278178608, pages 1-2). Shovel: 52 US App Store reviews (feed id
> 1467742357).
>
> **Coverage limits.** MyStudyLife's help centre
> (`https://care.mystudylife.com/en/`) failed with a TLS handshake error
> from every client tried, so its timetable mechanics come from its
> [FAQ](https://mystudylife.com/faqs/) and marketing pages only. MyStudyLife
> has no public feedback board, forum or roadmap; support is an email
> address and in-app ([home](https://mystudylife.com/)). Shovel's help centre
> has an expired certificate. Reddit refused scripted access, so no Reddit
> voice appears here. Counts are keyword and reading counts over the sample
> above, not over all users. **The absence of a theme is not evidence of
> its absence.**
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

Everything from a store review is **user voice**, never proof of how a
feature works. Reviews are cited by store, date and title, because Apple's
feed has no per-review URL; each section links the feed it came from
([msl], [pp], [shovel]).

## The venue's character

MyStudyLife has no place where users talk to the vendor in public, so the
App Store is where they go. The sample is dominated by one event: the
August 2024 v2 rewrite. 98 of the 150 reviews are 1-star, and most of those
are about the rewrite. The developer replies to some reviews in the store.

Power Planner is the reverse: a quiet, well-rated app (79 of 100 recent
reviews are 5-star) run by one developer, whose GitHub issues are feature
requests that stay open for years (#61 since 2021, #117 since 2022). Shovel's
reviews split between praise for its planning model and complaints that the
mobile app is abandoned.

## Pain points ranked by recurrence

### A. "The v2 update ruined it, bring back the old version"

Well over 50 MyStudyLife reviews ([msl]) from August 2024 to February 2026: UI
regressions, a paywall on features that used to be free, a forced
migration. Examples: "BRING BACK THE OLD VERSION!!!" (2024-09-04), "V2 Broke
everything" (2024-09-24), "Abandoning the App after 10 Years" (2024-11-06),
"they ruined it" (2026-02-11). Users left for Power Planner, Todoist and
"smart timetable" (2024-08-20, 2026-02-18, 2024-12-09).

The design choice that causes it, as reviewers describe it (user voice,
not documented by the vendor): a rewrite shipped to every user at once,
old accounts recreated, and the v1 web app later taken down.

### B. Class times shift by hours

At least 15 MyStudyLife reviews ([msl]): "App changed my time zone" (2026-06-16);
"due to daylight saving time ending, all of my class times …" (2024-11-10);
"Things are now 5 hours after they should be" (2025-01-22); "class at 3 am"
(2025-01-26); "Classes actually scheduled for Mon and Wed are showing as Sun
and Tue" (2024-09-18); "times were all wrong" (2026-08-17). The vendor's own
notes for 7.3.4 and 7.3.5 fixed "time zone related bugs"
([App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).
Power Planner has the same class of bug:
[#90](https://github.com/powerplanner/powerplannerapps/issues/90) (DST,
Arizona), [#73](https://github.com/powerplanner/powerplannerapps/issues/73)
(events on the wrong day in another timezone),
[#127](https://github.com/powerplanner/powerplannerapps/issues/127)
(Android 14 broke time zones).

The design choice that causes it: not documented. A plausible cause, an
inference only, is a recurring wall-clock time converted to an instant
somewhere between server and client. The same failure appears in two
unrelated codebases.

### C. Data loss, and accounts that will not migrate or sync

At least 15 reviews ([msl]): web and mobile detached, "account isn't found",
classes deleted, constant sign-outs. "erase old accounts" (2024-09-04),
"THE BROKE THE SYNC FEATURE" (2024-10-01), "Constant signouts"
(2024-08-29), "signs me out every 30 minutes" (2025-08-31), "I lost my
account and all my data" (2026-04-11); on Google Play, "Loss of Data"
(2024-10-12). Shovel ([shovel]): "Lost all assignments because of 'free trial'"
(2021-08-16).

The design choice that causes it, as a reviewer reports it (user voice):
the v1 web and v2 mobile apps did not sync, "app doesn't sync unless both
platforms using the same version" (2024-10-05). The mechanism is not
documented.

### D. The free tier caps tasks at five

About 10 MyStudyLife reviews ([msl]): "5 free tasks remaining" (2026-06-02),
"Making me pay" (2026-03-13), "can't even sync your web account to your
phone without having to pay" (2024-08-28), "give us a one time purchase
option" (2025-10-14). The cap is on the plan page
([MSL+](https://mystudylife.com/msl-plus/)). Power Planner reviewers ([pp]) praise
the opposite, its $4.99 one-time premium ("No Monthly Subscription"
2025-01-23; 2025-08-28).

The design choice that causes it: metering the list itself rather than an
extra.

### E. A fixed subject list

About 8 MyStudyLife reviews ([msl]): no course number ("Subjects?" 2025-08-19),
"Fixed Options for Subjects" (2025-10-16), a language class impossible
(2025-10-14), "add Arts" (2025-09-26), a grad student with "no option to add
custom classes" (2025-09-01), subject shown before class name (2025-08-24,
2025-08-10).

The design choice that causes it: subjects from a preset taxonomy, with
custom subjects hard to find (a developer reply says they "are still an
option", "Downhill plummet", 2024-08-20).

### F. Class setup is painful

About 8 MyStudyLife reviews ([msl]): a start date that cannot be in the past and an
end date a week early ("Huh?" 2025-01-26), times that jump while editing,
two hours to enter a schedule ("Don't waste your time" 2026-08-17; two
reviews 2026-08-18; 2026-09-03).

The design choice that causes it: not verifiable from outside; the help
centre that would describe the setup flow was unreachable.

### G. Tasks look like classes, and there is no list of what is due

About 6 MyStudyLife reviews ([msl]): "Downhill plummet" (2024-08-20), "assignments
show up on the schedule as if they were classes" (2024-08-28), "No friendly
way to see the future assignments" (2024-08-28), "won't tell you what the
direct assignment is" (2024-08-31).

The design choice that causes it, as reviewers describe it (user voice):
assignments drawn on the schedule in the same form as classes.

### H. Notifications do not fire

About 6 MyStudyLife reviews ([msl]): "not sending reminder notifications"
(2026-09-10), "No notifications for tasks" (2025-05-07), 2026-01-08. Power
Planner ([pp]) 1-star "There are NO reminders" (2024-05-01). Early Shovel reviews
asked for notifications (2019-2020).

### I. Holidays do not suppress classes; no single-day holiday

"the vacations feature doesn't even make it so you don't have school" (App
Store US, 2024-11-10); "no longer lets us set 1 day holidays" (App Store GB,
2024-06-10). The FAQ describes holidays as the way to cancel classes
([FAQ](https://mystudylife.com/faqs/)), so these are regressions of a
documented feature.

### J. Rotation timetables

Praised when they work ("2 completely different weeks … could not find
another app that does that", GB 2019-10-28) and broken after updates
("Rotation days … Classes aren't labeled, times are off by hours", US
2025-01-21). Shovel ([shovel]): "Please add 6 day cycles" (2020-02-24). Power Planner
ships Week A/B only;
[#125](https://github.com/powerplanner/powerplannerapps/issues/125) reports
an Android widget bug with 2-week schedules.

### K. Grades: GPA, weighted categories, "what if"

The most praised Power Planner feature ([pp]; "What if? mode" 2018-05-30;
2025-08-28; 2026-07-18). Its issues ask for more:
[#62](https://github.com/powerplanner/powerplannerapps/issues/62) grade
statistics, [#84](https://github.com/powerplanner/powerplannerapps/issues/84)
disable GPA for a dropped class,
[#96](https://github.com/powerplanner/powerplannerapps/issues/96) a
"master" class. A MyStudyLife user paid and found no grade tracking
(2025-06-11).

### L. A native Mac app

Power Planner ([pp]): "PLEASE make a compatible Mac version", "more glitches on
Mac" (2026-01-08), "a native app for Mac would be so useful" (2025-02-13),
a force-quit loop on Mac (2026-08-16). Shovel ([shovel]): "Needs an app for MAC"
(2020-08-09). MyStudyLife has no Mac listing
([App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).

### M. Work and personal tasks that outlive a semester

Power Planner [#117](https://github.com/powerplanner/powerplannerapps/issues/117)
("a separate 'tasks' category in place of classes") and
[#131](https://github.com/powerplanner/powerplannerapps/issues/131) (to-do
app integration). Shovel ([shovel]): "adding a normal (no school related) task …
Almost like a to-do-list" (2020-02-04), and a professor who models research
as "classes" (2020-10-20).

The design choice that causes it: everything hangs off Year → Semester →
Class, so a task with no class has nowhere to live.

### N. Smaller recurring asks

- A focus timer: Power Planner
  [#61](https://github.com/powerplanner/powerplannerapps/issues/61), open
  since 2021; Shovel "a pomodoro timer" (2022-10-07). MyStudyLife added one
  in v2.
- Per-occurrence edits of a recurring class ("ability to add individual day
  lectures for a reoccurring class", MSL 2025-08-19, [msl]) and labs as part of a
  class (PP review 2024-12-13).
- Notes longer than a line ("Task Notes won't let me add more than 25
  characters", MSL 2026-09-03 and 2026-09-04); Markdown in details (PP
  [#126](https://github.com/powerplanner/powerplannerapps/issues/126)).
- Undo complete, bulk edit of repeats, copy and paste of repeating tasks
  (MSL 2025-03-08; PP 2-star 2022-09-07, "no way to edit multiple
  assignments at once").
- Widgets, Apple Watch and search (PP reviews 2023-2024, 2023-09-14,
  2023-11-28, 2026-07-11); a parent view (MSL "PLEASE ADD A VERSION FOR
  PARENTS", 2025-08-25, since shipped as
  [Family Connect](https://mystudylife.com/parent/)).

## Classification

Class: **(a)** Omakase's design already answers it; **(b)** structural to
their architecture, impossible in Omakase's; **(c)** Omakase also lacks it.

| Need | Evidence | Class | Omakase today |
|---|---|---|---|
| Updates that do not break the old client or force a new account | A, C | (a) partly | Shipped as a rule, not a feature (a rule can be broken, so not (b)): AGENTS.md invariant 8 treats the API as a contract with native clients that ship on their own schedule. Untested at scale: one client exists. |
| Class times that do not drift across DST or a timezone change | B | (a) in design, untested; MSL's cause is not documented, so not (b) | Shipped: `ClassSchedule` stores a `TimeField` and `day_of_week`, and `class-occurrences/` computes occurrences per request, not stored (`docs/ARCHITECTURE.md`). **Absent: no test covers a timetable crossing a DST boundary or a timezone change.** (Invariant 2 governs the client's date for "today", not class times.) |
| Offline use without losing data | C | (a) partly | Shipped for the Mac Today checklist only: SwiftData cache and an ordered outbox that replays with idempotency keys (M1). Every other screen is planned M3-M5. |
| A full free list, no per-task cap | D | - (business model) | Absent: no pricing or billing exists. |
| User-named courses with a code | E | (a) | Shipped (API): `Discipline` has a user-set `name`, `code`, `professor` and `color` (`backend/study/models.py`). No client screen; study parity is planned M5. |
| Easy timetable setup | F | (c) | API shipped (`classschedules/`); the setup UI is planned M5. |
| Deadlines kept apart from timetabled classes | G | (a) in design | Shipped (API): tasks and study blocks are items with a `due_date`; classes are occurrences. Drawing classes behind blocks on the calendar is planned M4. |
| Reminders and notifications | H | (c) | Planned M3 (notifications). Absent from the API. |
| Holidays and cancelled occurrences | I, N | (c) | Absent. Promised only (docs/IDEA.md §3). |
| Rotation (Week A/B, N-day) timetables | J | (c) | Absent: `ClassSchedule` is weekly only. |
| Grades, GPA, "what if" | K | (c) | Absent: only `Discipline.target_grade`. Grade tracker promised only (docs/IDEA.md §3). |
| Native Mac app | L | (a) | Shipped: native SwiftUI Mac app, but with sign-in and a Today checklist only. |
| Work tasks beside study, across semesters | M | (a) | Shipped (API): workspaces → projects → tasks beside semesters → disciplines, sharing `timeblocks/`. The Mac client shows only the Today checklist. |
| Focus timer tied to a task | N | (a) partly | Shipped (API): `pomodoro/sessions/` with an optional task. The Mac timer is planned M3. |
| Per-occurrence class exceptions | N | (c) | Absent. Promised only (docs/IDEA.md §3). |
| Labs as part of a course | N | (a) | Shipped (API): `ClassSchedule.class_type` (lecture, lab and others) under one discipline. |
| Long notes | N | (a) | Shipped (API): `notes` is a `TextField` on tasks, study blocks and time blocks. |
| Bulk edit, undo complete | N | (c) partly | `reorder-bulk/` shipped; no bulk edit. The Mac Today row is a checkbox toggle (`TodayView.swift`). No undo or trash. |
| Widgets, Watch, search | N | (c) | Absent. |

## What the maintainers have not solved

- **MyStudyLife: time zones.** Two releases fixed "time zone related bugs"
  in February 2025, and reviews of shifted class times continue into 2026
  ("App changed my time zone" 2026-06-16; "times were all wrong"
  2026-08-17).
- **MyStudyLife: trust after v2.** 1-star reviews about the rewrite run
  from August 2024 to at least February 2026.
- **Power Planner: anything outside Year → Semester → Class.** #117 (work
  tasks) and #131 (to-do integration) are open; so is #61, a timer, since
  2021.
- **Power Planner: time zones**, #90, #73 and #127.
- **Shovel: its mobile app.** Reviewers call it dead from 2022 to 2026.

## Do-not-repeat lessons

1. Never ship a rewrite that forces users to recreate an account, or that
   leaves two client generations unable to sync. Keep old clients working
   against the API (AGENTS.md invariant 8).
2. Do not let a class's wall-clock time drift across a DST or timezone
   change. Two unrelated codebases did (B). Omakase stores a `TimeField`
   and a `day_of_week`, and has no test across either change yet.
3. Do not meter the list. About 10 reviews in the sample complain of the
   five-task cap (D).
4. Let users name their own courses; never ship a fixed subject taxonomy.
5. Do not draw a deadline as if it were a class. A due date and a time
   block are different things on the calendar.
6. When a work task has to hang off a class to exist, users bend the model.
   Omakase's separate work hierarchy is the answer, but only once a client
   can show it.

[msl]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=910639339/sortby=mostrecent/json
[pp]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=1278178608/sortby=mostrecent/json
[shovel]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=1467742357/sortby=mostrecent/json

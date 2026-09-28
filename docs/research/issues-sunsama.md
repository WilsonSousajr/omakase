# Sunsama - what its users keep asking for

> Captured **2026-09-25**, against Omakase's `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **Venue and sample.** Sunsama's public Canny board,
> https://roadmap.sunsama.com, with three boards: improvements,
> integrations and mobile-apps. Posts were fetched from Canny's public JSON
> endpoint `POST https://roadmap.sunsama.com/api/posts/get` with
> `sort: "score"`. The endpoint returned posts from all three boards mixed,
> despite `boardID`, and by default returns open and in-progress posts
> only. **The sample is the top 50 open posts by votes.** The top 10 of
> `https://roadmap.sunsama.com/improvements?sort=top` and
> `/integrations?sort=top` matched the API order. The top complete and
> closed posts were fetched separately (`status: "complete"`,
> `status: "closed"`) to show demand already served.
>
> **Method.** Votes are Canny "score" (voters). Recurrence is the number of
> top-50 posts in a theme; summed votes break ties only, since one user may
> vote on several posts.
>
> **Coverage limits.** Only three post pages were opened in full (offline,
> analytics, student discount; the last gave status only). Every other row
> is the title, detail snippet and score from the API, so official
> responses on most posts were not read. Reddit could not be reached.
> **The absence of a theme here is not evidence that users do not want
> it.**
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## The venue's character

The board is large and active. The improvements board reports 3,348
posts, 2,706 of them active (the board's own page, "powered by Canny").
Vote counts run into four figures: the most-voted post on the whole board,
[Task priority](https://roadmap.sunsama.com/improvements/p/task-priority)
(1,870), is complete. Posts carry statuses (open, in progress, complete,
closed, and on one page "Merged"), so the vendor visibly triages. Some
requests stay open for years: the API request dates from 2019 and has 111
comments, and the offline request from 2020.

## Pain points ranked by recurrence

### A. Integrations with more tools

18 of the top 50, about 4,400 votes.
[Obsidian 610](https://roadmap.sunsama.com/integrations/p/obsidian),
[Things 3 484](https://roadmap.sunsama.com/integrations/p/things-3-integration),
[TickTick 482](https://roadmap.sunsama.com/integrations/p/ticktick-integration),
[Evernote 320](https://roadmap.sunsama.com/integrations/p/evernote-integration),
[Apple Notes 243](https://roadmap.sunsama.com/integrations/p/apple-notes-app),
[CalDAV/iCloud 219, in progress](https://roadmap.sunsama.com/integrations/p/caldavicloud-integration),
[Todoist export 207](https://roadmap.sunsama.com/improvements/p/create-tasks-in-todoist-from-sunsama-todoist-task-export),
[Asana 2-way 164](https://roadmap.sunsama.com/improvements/p/asana-2-way-sync).
The rest of the top 50 in this theme, from the API sample: Hubspot,
Airtable, Spark, Google Drive, Basecamp, WhatsApp, Keep, Chrome and Apple
Mail, and a Todoist channels mapping.

**The design choice that causes it:** Sunsama is a layer over other tools
by design - tasks are pulled in from integrations during planning
([daily planning](https://help.sunsama.com/docs/usage-guides/daily-planning))
- so every missing tool is a missing source.

### B. Task structure and organisation

9 of the top 50, about 3,300 votes.
[Subtasks should be full tasks 905](https://roadmap.sunsama.com/improvements/p/subtasks-should-be-full-tasks),
[Color code tasks 652](https://roadmap.sunsama.com/improvements/p/color-code-tasks),
[Tags / multiple channels 594](https://roadmap.sunsama.com/improvements/p/tags-multiple-channels-for-a-task),
[Bulk edit 277](https://roadmap.sunsama.com/improvements/p/batchbulk-edit-select-multiple-tasks-to-move-or-edit),
[Multiple backlogs/folders 272](https://roadmap.sunsama.com/improvements/p/create-multiple-backlogs-or-folderssections-in-backlog),
[Task sorting 236](https://roadmap.sunsama.com/improvements/p/task-sorting-planned-time-oldest-tasks-by-channel-context-objective-etc),
[Blocked/waiting view 194](https://roadmap.sunsama.com/improvements/p/blockedwaitingpending-task-view),
[Task templates 172](https://roadmap.sunsama.com/improvements/p/task-templates),
[Filter multiple channels 143](https://roadmap.sunsama.com/improvements/p/filter-by-multiple-channels-simultaneously-exclude-channels-via-filtering).

**The design choice that causes it:** one channel per task, subtasks made
by merging, folders only in the backlog, and no project entity
([`sunsama.md`](sunsama.md) §2).

### C. Calendar and day semantics

5 of the top 50, about 1,300 votes.
[Vacation/OOO mode 584](https://roadmap.sunsama.com/improvements/p/vacation-holiday-ooo-sick-leave-mode),
[Time slots to timebox several tasks into 222](https://roadmap.sunsama.com/improvements/p/time-slots-visualized-blocks-of-time-to-schedule-timebox-multiple-tasks-into),
[Repeat every N days 204](https://roadmap.sunsama.com/improvements/p/allow-recurring-tasks-to-be-repeated-by-number-of-days),
[Honour calendar colours 156](https://roadmap.sunsama.com/improvements/p/show-calendar-events-in-the-same-color-as-google-and-outlook-calendar),
[Customize which days you work 150](https://roadmap.sunsama.com/improvements/p/customize-which-days-you-work).

**The design choice that causes it:** a working session belongs to one
task, and the day is a fixed calendar day with rollover at midnight
([`sunsama.md`](sunsama.md) §2, §3).

### D. Mobile, watch, widgets, notifications

5 of the top 50 (plus one in-app), about 1,550 votes.
[Apple Watch 361](https://roadmap.sunsama.com/mobile-apps/p/apple-watch-app-widget-notifications),
[Mobile notifications 333](https://roadmap.sunsama.com/mobile-apps/p/notifications-on-mobile-app),
[iOS/Android widget 308](https://roadmap.sunsama.com/mobile-apps/p/android-and-ios-widget),
[In-app notifications 288](https://roadmap.sunsama.com/improvements/p/in-app-notifications),
[Mobile parity with desktop 256](https://roadmap.sunsama.com/mobile-apps/p/unified-design-on-mobile-make-mobile-app-similar-to-desktop).

**The design choice that causes it:** the mobile app is a "Companion app
to the desktop app"
([App Store](https://apps.apple.com/us/app/sunsama/id1475755747)), and
focus and break features need the desktop app running
([focus bar](https://help.sunsama.com/docs/usage-guides/focus-bar)).

### E. Longer-horizon objectives and planning

4 of the top 50, about 3,970 votes - the strongest single signal on the
board.
[Monthly objectives & planning 1,744](https://roadmap.sunsama.com/improvements/p/monthly-objectives-and-planning)
(the #1 open post),
[Yearly 1,202](https://roadmap.sunsama.com/improvements/p/yearly-objectives),
[Quarterly 864](https://roadmap.sunsama.com/improvements/p/quarterly-objectives-and-planning),
[Persistent weekly objectives 161](https://roadmap.sunsama.com/improvements/p/persistent-repeating-weekly-objectives).

**The design choice that causes it:** objectives are weekly only
([weekly objectives](https://help.sunsama.com/docs/usage-guides/weekly-objectives)).

### F. Analytics and time insight

3 of the top 50, about 1,345 votes.
[Improved analytics 685](https://roadmap.sunsama.com/improvements/p/improved-analytics-and-data-insights)
("Currently one can see data only by week"),
[Actual vs planned 402](https://roadmap.sunsama.com/improvements/p/compare-actual-time-vs-planned-time),
[Time planned today separate from total 258](https://roadmap.sunsama.com/improvements/p/time-planned-today-separate-from-total-task-time).

**The design choice that causes it:** the documented time insight lives
inside the daily and weekly rituals. An analytics screen exists, but no
help article describes it, so what it shows was not verified
([`sunsama.md`](sunsama.md) §7).

### G. Notes and knowledge

2 of the top 50 (plus Obsidian and Evernote in A), about 1,030 votes.
[Browse past meeting notes 687](https://roadmap.sunsama.com/improvements/p/browse-all-past-meeting-notes),
[General notes 344](https://roadmap.sunsama.com/improvements/p/general-notes-features).

### H. Architecture: API and offline

2 of the top 50, about 1,120 votes.
[Sunsama API 887](https://roadmap.sunsama.com/improvements/p/sunsama-api)
(111 comments, open since 2019; only an MCP server exists),
[Offline mode for desktop 230](https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app)
(open since 2020-06-11; "the whole app is failing to load").

**The design choice that causes it:** an Electron desktop client
([FAQ](https://help.sunsama.com/docs/faq/faq)) that does not work
offline (the open offline post above), and no public API beyond an MCP
server ([MCP](https://help.sunsama.com/docs/integrations/mcp)).

### I. Habit tracking

1 post, 654 votes.
[Habit tracking 654](https://roadmap.sunsama.com/improvements/p/habit-tracking).

### J. Customisable rituals

1 post, 173 votes.
[Customize plan-your-day steps / prompts 173](https://roadmap.sunsama.com/improvements/p/customize-plan-your-day-steps-daily-planning-share-your-plan-prompts-template).

**The design choice that causes it:** the planning and shutdown steps are
fixed ([daily planning](https://help.sunsama.com/docs/usage-guides/daily-planning)).

### Demand already served

Top complete posts (status from the Canny API; only the student-discount
post was opened as a page):
[Task priority 1,870](https://roadmap.sunsama.com/improvements/p/task-priority),
[Merge tasks into subtasks 1,259](https://roadmap.sunsama.com/improvements/p/drag-tasks-onto-tasks-to-merge-into-subtasks),
[Apple Calendar/iCal 1,249](https://roadmap.sunsama.com/integrations/p/apple-calendar-ical-integration),
[Pomodoro timer 1,067](https://roadmap.sunsama.com/improvements/p/pomodoro-timer),
[Student Discount 859](https://roadmap.sunsama.com/improvements/p/student-discount),
[Kanban/project-style backlog 803](https://roadmap.sunsama.com/improvements/p/kanbanproject-style-backlog),
[Daily journal 706](https://roadmap.sunsama.com/improvements/p/daily-journal),
[Plan/Shutdown on mobile 619](https://roadmap.sunsama.com/mobile-apps/p/plan-your-day-workflow-on-mobile-and-shutdown-ritual-on-mobile),
[Visually mark rolled-over tasks 609](https://roadmap.sunsama.com/improvements/p/visually-distinguish-tasks-that-got-rolled-over-from-yesterday),
[Weekly goals + reflection 466](https://roadmap.sunsama.com/improvements/p/weekly-goals-reflection),
[Notify when timer hits estimate 417](https://roadmap.sunsama.com/improvements/p/notification-when-timer-hits-estimate).
Students are in the user base and asked to pay less (859 votes).

A notable **closed** post:
[Option to change rollover / end-of-day time to after midnight, 152](https://roadmap.sunsama.com/improvements/p/option-to-change-rollover-time-end-of-day-time-to-after-midnight).
The page was not opened, so the reason is unknown.

## Classification

Class: **(a)** Omakase's design already answers it, **(b)** structural to
Sunsama's architecture and impossible in Omakase's, **(c)** Omakase also
lacks it.

| Need | Evidence | Class | Omakase today |
|---|---|---|---|
| Integrations with other task and note tools | A | (c) | absent; Google Calendar import and sync, Notion import promised IDEA §5, §19 |
| Calendar import (CalDAV, iCloud, Google) | A | (c) | absent; a read-only Calendar.app overlay is planned M5 |
| Projects and folders | B | (a) | shipped (API): `workspaces/`, `projects/`; no client screen until M5 |
| Subtasks as real items | B | (c) | absent: an Omakase subtask is a title, a done flag and an order (`backend/tasks/models.py`, `Subtask`), the same second-class shape users reject here |
| Several tags per task, colour | B | (a) | shipped (API): `tags/`, many per task, each with a colour (`backend/tasks/models.py`, `Tag`); not in the Mac client |
| Bulk edit | B | (c) | absent (API has `reorder-bulk/` only) |
| Task templates | B | (c) | promised IDEA §14 |
| Blocked or waiting status | B | (c) | absent (kanban status exists in the API) |
| A fixed recurring slot to plan work around | C | (a) partly | shipped (API): weekly `classschedules/` and computed `class-occurrences/`; drawn on the calendar planned M4 |
| Repeat every N days | C | (c) | promised IDEA §2 |
| Vacation mode, custom work days | C | (c) | absent (holidays and cancelled classes not built) |
| Mobile app, watch, widgets | D | (c) | later (iOS, Android after M6) |
| Notifications | D | (c) | planned M3 |
| Mobile parity with desktop | D | (c) | absent: shared SwiftUI packages (Features → Store → API) exist, but iOS is later and Android cannot share them, so nothing guarantees parity |
| Monthly, quarterly, yearly objectives | E | (c) for work, (a) partly for study | shipped (API): `semesters/` and `disciplines/` give a term horizon; no goals above the project; weekly plan promised IDEA §6 |
| Estimate against actual, custom date ranges | F | (c) | `stats/daily/` (hours, streak, weekly work and study hours) shipped (API); estimation accuracy and dashboards promised IDEA §9 |
| Notes | G | (c) | promised IDEA §16 (time blocks have a notes field in the API) |
| A public API | H | (a) partly | shipped: the REST API under `/api/v1/` is every client's contract, so an API exists by construction; no third-party access (API keys, OAuth for other apps) or published reference exists, and Sunsama's gap is a product choice, not architecture, so not (b) |
| Offline use | H | (b) | Sunsama's desktop client does not run without the server; Omakase's Mac client reads from a local SwiftData cache and queues writes in an ordered outbox (M1), shipped for the Today checklist only; the offline indicator is planned M3 |
| Habit tracking | I | (c) | promised IDEA §15 |
| Customisable ritual steps | J | (c) | absent; the daily review's fields are fixed in the API (`stats/reviews/`), the review screen is planned M3 |
| Pomodoro timer | served | (a) partly | `pomodoro/sessions/` shipped (API); the Mac timer is planned M3 |
| Daily journal, shutdown | served | (a) partly | `stats/reviews/` shipped (API: rating, win of the day, shutdown flag); review and shutdown screens planned M3 |
| A day that ends after midnight | closed | (c) | absent; "today" is the client's calendar date (invariant 2) |

## What the maintainers have not solved

- **Offline.** Open since 2020-06-11 with 230 votes; the latest desktop
  changelog offers "improved network reconnection" instead
  ([changelog](https://roadmap.sunsama.com/changelog)).
- **A public API.** Open since 2019 with 887 votes; an MCP server shipped
  instead ([MCP](https://help.sunsama.com/docs/integrations/mcp)).
- **Goals longer than a week.** The #1, #2 and #5 open posts by votes (E).
- **Subtasks as full tasks.** 905 votes, open, after merge-to-subtask
  shipped (B).
- **A day that ends after midnight.** Closed, reason not read.

## Do-not-repeat lessons

1. **Do not build the planner online-only.** Sunsama's users have asked
   for offline since 2020 and still have not got it (H).
2. **Do not tie the timer and breaks to one platform's app running** (D).
3. **Do not cap the planning horizon at one week** when the user's life
   runs in terms and quarters (E).
4. **Do not make subtasks second-class** or forbid them on some task kinds
   (B).
5. **Do not drop scheduled time silently.** Moving a task drops its
   session, and a failed deconflict unschedules without a word
   ([`sunsama.md`](sunsama.md) §3).
6. **Do not hard-code the ritual's steps** without a plan for customising
   them (J).

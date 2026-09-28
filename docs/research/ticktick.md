# TickTick - deep dive

> Captured **2026-09-25**, against Omakase's `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **What was read.** help.ticktick.com is a Next.js site. Each article page
> embeds the full text of all 96 help-centre articles in its `__NEXT_DATA__`
> payload, with `postId` and `modifiedTime`. One page
> ([7055782166172532736](https://help.ticktick.com/articles/7055782166172532736))
> was fetched and the articles read from that payload; each is cited by its
> own `https://help.ticktick.com/articles/<postId>` URL. Most were modified
> in 2026-05..09. The help centre of Dida365 (滴答清单), the China edition,
> is built the same way and was read the same way
> ([6950372717036044288](https://help.dida365.com/articles/6950372717036044288)).
> Also read: the upgrade and education pages, the features page, the
> download page, and the iOS and Mac App Store listings.
>
> **Coverage limits.** No primary page states the Mac app's UI framework.
> Offline behaviour is not documented anywhere that was read. "Daily review
> reminders" appears only on a marketing page. Reddit refused scripted
> access. The Mac App Store listing shows too few US ratings to display.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## 1. Purpose and target user

The help centre calls TickTick "a simple and easy-to-use time management
tool. It includes modules for Tasks, Calendar, Eisenhower Matrix, Pomodoro,
and Habit Tracker. You can use it to manage your work and life"
([Beginner's Guide](https://help.ticktick.com/articles/7054286604315131904)).

Its stated design principle is a general life manager with user choice:
"what users need is not just task management, but everything in their
lives". Users can hide or reorder modules. The same article claims "nearly
20 million users worldwide" (vendor-self-reported)
([design principles](https://help.ticktick.com/articles/7054327235582361600)).

The target user is general: work, life and study together. Students are one
audience, served by an education discount (§9) and example copy ("For
students: homework, vocabulary memorization, general courses",
[Timer](https://help.ticktick.com/articles/7055781980423585792)). The
international product has no separate study mode (§6).

## 2. Data model

- Five levels: **Folder → List → Section → Task → Subtask**
  ([lists](https://help.ticktick.com/articles/7055782309420597248)).
- Subtasks nest up to **5 levels**, and "each subtask at every level has the
  same functions as a normal task": time and duration, focus, tags,
  priority and assignee. Separately, *check items* (checklists) drive the
  parent's progress: "only the completion of the check items will affect
  the task progress"
  ([Multilevel Tasks](https://help.ticktick.com/articles/7055782219767349248)).
- **Tags**, many per task, with second-level (parent) tags, colour, pin and
  sort ([tags](https://help.ticktick.com/articles/7055782255804809216)).
  **Filters** are saved queries
  ([filters](https://help.ticktick.com/articles/7055782240994721792)).
- **Note lists** are a list type beside task lists. A note has no
  completion state. One suggested use is "'Subject Materials' - set up a
  separate list to store materials for a particular course"
  ([notes](https://help.ticktick.com/articles/7055780476358754304)).
- Other first-class objects: **Habits**
  ([habits](https://help.ticktick.com/articles/7055781896457814016)),
  **Countdowns** and anniversaries ("a trip, an exam, a performance",
  [countdowns](https://help.ticktick.com/articles/7321455627362893824)),
  and **focus records** (§5).
- **Duration tasks** are how TickTick timeboxes: a task has a start time
  and an end time. There is no separate time-block entity; a task *is* its
  block ([Task Details](https://help.ticktick.com/articles/7055782408586526720),
  [Week View](https://help.ticktick.com/articles/7055782149730861056)).
- **No study objects in the international help centre.** A search of all
  96 articles for "timetable", "course", "class schedule" and "semester"
  finds no timetable feature. The only student-specific data advice is a
  2020 blog post: set "week 1" in Date & Time settings to the week courses
  begin, and enter lectures as recurring tasks
  ([blog](https://blog.ticktick.com/2020/08/31/new-school-year-new-chapter/)).
  The timetable exists in Dida365 (§6).

## 3. Planning surface

- **Calendar views:** Day, 3-Day and Week. Mobile has timeline and grid
  week layouts, desktop has Multi-Day and Multi-Week, and there are Month,
  Year (heatmap), List-by-day and Agenda views
  ([1](https://help.ticktick.com/articles/7055782166172532736),
  [2](https://help.ticktick.com/articles/7055782149730861056),
  [3](https://help.ticktick.com/articles/7399726920725692416),
  [4](https://help.ticktick.com/articles/7213444784319365120)). A per-list
  Timeline (Gantt-lite) view also exists
  ([timeline](https://help.ticktick.com/articles/7055780375439605760)).
- **Timeboxing by drag.** A long-press or click-drag on the timeline
  creates a duration task; dragging the edge resizes it and dragging the
  block reschedules it. "Arrange Tasks" is a side panel of undated tasks
  to drag onto the calendar
  ([Week View](https://help.ticktick.com/articles/7055782149730861056),
  [arrange](https://help.ticktick.com/articles/7063851189372190720)).
  Desktop has a **Split View** (list beside calendar): drag list to
  calendar, calendar to list, or onto a tag or smart list
  ([Split View](https://help.ticktick.com/articles/7358389904469917696)).
- Calendar options include colour by list, tag or priority, hidden hour
  ranges, up to 5 time zones, "Show Habit", and "Show Focus Records", which
  overlays focus sessions on the calendar
  ([calendar settings](https://help.ticktick.com/articles/7055782085826445312)).
- **Mac gaps stated in the docs.** Multi-select batch reschedule and
  Postpone are "available on Windows and Web. Drag-and-drop is not yet
  supported on macOS". Mini Calendar is "exclusive to the Web & Windows
  version"
  ([calendar settings](https://help.ticktick.com/articles/7055782085826445312),
  [arrange](https://help.ticktick.com/articles/7063851189372190720)).
- **No auto-scheduler.** No help article describes one. The nearest things
  are **Suggested Tasks**, a Today panel that surfaces Recently Added,
  Postponed (by reschedule count), Long Overdue and Upcoming tasks with an
  "Add to Today" button
  ([Suggested Tasks](https://help.ticktick.com/articles/7401564165023727616)),
  and the **AI Assistant**. You prompt it ("Help me plan my day … Create a
  schedule based on priority and estimated duration") and it can act on
  tasks. It is on mobile, macOS and Web, not Windows
  ([1](https://help.ticktick.com/articles/7503016104470511616),
  [2](https://help.ticktick.com/articles/7475477082185662464)).
- **Estimates:** each task has an "Estimated Pomo/Duration" field
  ([FAQ](https://help.ticktick.com/articles/7055792921664028672)).

## 4. Daily ritual

No structured daily plan or shutdown ritual appears in the help centre.
The pieces that exist:

- The Today smart list plus **Suggested Tasks** (§3) is the de facto
  morning triage.
- "Daily review reminders" appears on the features page (marketing page,
  [features](https://ticktick.com/about/features?language=en_US)). No help
  article describes it, so how it works is not verified.
- The Week View is pitched for weekly reports ("Easy Review … completed
  tasks will appear lighter"), and the Month View for monthly reflection
  ([Week View](https://help.ticktick.com/articles/7055782149730861056),
  [Month View](https://help.ticktick.com/articles/7055782128335716352)).
- **Summary** is a generated, editable report of tasks over a date range,
  filtered by list, tag or assignee. It can include focus data, is
  inserted into a note or exported, and can be saved as a template.
  Inserting it into a note is mobile-only
  ([notes](https://help.ticktick.com/articles/7055780476358754304)).
- The AI Assistant has a "Review" prompt: "Based on my task completion,
  habit records, and focus records during 'XXX time range', help me review
  and reflect"
  ([AI Assistant](https://help.ticktick.com/articles/7503016104470511616)).
- None of the 96 articles describes an end-of-day rating, a "win of the
  day" or a shutdown state.

## 5. Focus

- **Pomodoro** (25/5, a long break after 4) and **Stopwatch** modes. Focus
  starts from the Focus tab, a task swipe, a right-click, the task detail
  or a reminder pop-up. "Sync Across Devices" starts, pauses and finishes a
  session on every device. The timer can be adjusted mid-session, and "Add
  Extra Time" or "Edit Focus Duration" works afterwards. A **Focus Note**
  lets you "jot down any thoughts or ideas that come to mind during your
  focus session"
  ([Pomodoro](https://help.ticktick.com/articles/7055782010496745472)).
- White noise (not on Web), full-screen clock styles, Screen Always On
  (mobile), a floating window (mobile), Flip Start (mobile: the timer runs
  only while the phone is face down), **Strict Mode** with an app allowlist
  (Pomodoro only, iOS 16+), and Live Activity
  ([focus settings](https://help.ticktick.com/articles/7055781994591944704)).
- **Timers** are preset focus items bound to a task or habit, with their
  own stats and "+ Add Record" for retroactive entries
  ([Timer](https://help.ticktick.com/articles/7055781980423585792)).
- **Focus Statistics:** trend by week, month and year, a daily focus
  timeline, most-focused time, a year heatmap, and distribution by List,
  Tag or Task. Records can be added, filtered and deleted in bulk. Desktop
  shows fewer stats (Pomos and duration by day and week)
  ([Focus Statistics](https://help.ticktick.com/articles/7055781966800486400)).

## 6. Study features

**International TickTick has no study model.** Students get the education
discount (§9), note lists for course material, countdowns to exams and
recurring tasks for lectures (§2). There is no timetable view, no course
entity and no term.

**Dida365 has a full class timetable, "课表视图"**
([help](https://help.dida365.com/articles/6950372717036044288), modified
2026-09-15). It is enabled in Settings → Import & Integrations → "课表".

- A course has a name, the weeks it runs, its periods (节数), a room and a
  teacher.
- Two imports: **photo or screenshot OCR** (grid or list layouts, one image
  at a time, the image is not stored) and **university portal (教务网)
  import**, which covers "近1000所学校" (nearly 1,000 schools).
- Class reminders can be set. Timetable settings include the term start
  date, the number of weeks and the period times.
- Courses can show in the Today, Tomorrow and Next 7 Days smart lists.
  "在日历中显示课表" (show the timetable in the calendar week view, beside
  tasks) is marked "PS.此功能为付费功能" (a paid feature).

The vendor has built a timetable and does not ship it in TickTick. No page
read says why.

## 7. Analytics

- An **achievement score** with 12 tiers rises when you add or complete
  tasks (more when on time), falls when tasks expire, and updates daily at
  00:00. There is a completion trend and a **completion rate** ("tasks you
  actually completed … to the tasks you originally scheduled")
  ([statistics](https://help.ticktick.com/articles/7082302534169133056)).
- Focus statistics are in §5. **Habit** statistics include a monthly
  check-in table and a yearly heatmap; the monthly all-habits view is
  premium and mobile-only
  ([habit stats](https://help.ticktick.com/articles/7055781785312952320)).
  Year View is a heatmap of completed tasks
  ([Year View](https://help.ticktick.com/articles/7399726920725692416)).

## 8. Platforms, native or not, offline

- **Platforms:** iOS/iPadOS, Android, Windows, macOS, Linux, Web and a
  browser extension ([download](https://ticktick.com/about/download)). The
  iOS listing covers iPhone, iPad, Watch and Vision, and shows 4.9★ from
  46K ratings, v8.2.12, and Editors' Choice
  ([iOS listing](https://apps.apple.com/us/app/ticktick-to-do-list-calendar/id626144601)).
  The Mac App Store listing shows v8.2.30, 83.6 MB, macOS 12+, and too few
  US ratings to display
  ([Mac listing](https://apps.apple.com/us/app/ticktick-to-do-list-calendar/id966085870)).
- **Native or not:** not verified. No page read states the desktop tech
  stack. The docs do show the Mac behind Windows and Web on some desktop
  features (§3).
- **Sync** is cloud sync ("seamless cloud synchronization across all your
  devices", iOS listing). Pomodoro sync is opt-in (§5). List view settings
  sync only if "Sync View Across Devices" is on
  ([FAQ](https://help.ticktick.com/articles/7055792921664028672)).
- **Offline: not documented.** The word "offline" appears in none of the 96
  help articles and on neither App Store listing. Offline behaviour and its
  conflict rules are not verified.

## 9. Pricing and student plans

- **Free:** 9 lists and 99 tasks per list, List and Kanban views,
  reminders, sync, 5 habits and 5 countdowns, 1 attachment a day.
  **Premium** adds 299 lists and 999 tasks, "Multiple Calendar Views", task
  duration, email reminders, themes, and more integrations and widgets, for
  **US$49.99 a year** ([upgrade](https://ticktick.com/upgrade)). The App
  Store also sells **US$4.99 a month**
  ([iOS listing](https://apps.apple.com/us/app/ticktick-to-do-list-calendar/id626144601)).
  The calendar views and duration tasks, which are the timeboxing surface,
  are on the Premium side of the comparison.
- **Students and educators:** 25% off the yearly plan, "only US$37.99 after
  discount" ([education](https://www.ticktick.com/education)). It needs an
  education email and documents, excludes training programmes, is paid via
  Stripe only, lasts 1 year, must be reapplied for (up to 4 times), and
  cannot be applied to an active plan
  ([education help](https://help.ticktick.com/articles/7375802644289290240)).

## 10. Integrations

- **Calendar in:** Local (Android, iOS and Mac only), Google (subscribe
  with two-way event editing, or a two-way list ↔ calendar "Integration"),
  iCloud, Outlook, Exchange, CalDAV and URL
  ([1](https://help.ticktick.com/articles/7055781614550253568),
  [2](https://help.ticktick.com/articles/7055781593733922816),
  [3](https://help.ticktick.com/articles/7209482814528421888)).
- **Calendar out:** an ICS subscription URL per list
  ([ICS](https://help.ticktick.com/articles/7055781574649839616)).
- **Import:** Todoist, Microsoft To Do, Wunderlist, OmniFocus, Toodledo,
  iCal, Any.do and Reminders, some on the web only
  ([import](https://help.ticktick.com/articles/7055781405648748544)).
- **Other:** Notion two-way sync, Spark, Telegram, Siri and URL scheme,
  Shortcuts, Apple Health import
  ([1](https://help.ticktick.com/articles/7263009660070789120),
  [2](https://help.ticktick.com/articles/7467494539406606336)). An **open
  API** ([docs](https://developer.ticktick.com/docs#/openapi), linked from
  [help](https://help.ticktick.com/articles/7055781495671095296)), an **MCP
  server** for Claude and ChatGPT
  ([MCP](https://help.ticktick.com/articles/7438129581631995904)), and a CLI
  (`npm i -g @ticktick/ticktick-cli`,
  [CLI](https://help.ticktick.com/articles/7465251130025443328)).

## 11. Strengths worth borrowing

1. **Focus records drawn on the calendar** ("Show Focus Records") put the
   plan and what happened on one timeline
   ([calendar settings](https://help.ticktick.com/articles/7055782085826445312)).
   Omakase's API already stores both (`timeblocks/`, `pomodoro/sessions/`);
   the calendar that could draw them is planned (docs/ROADMAP.md M4).
2. **Split View with drag anywhere:** list to calendar, calendar back to
   list, and onto a tag or smart list
   ([Split View](https://help.ticktick.com/articles/7358389904469917696)).
3. **Suggested Tasks ranks by reschedule count** ("Postponed Tasks …
   sorted by how many times their dates have been changed")
   ([Suggested Tasks](https://help.ticktick.com/articles/7401564165023727616)).
   Omakase's API has `tasks/carried-over/?date=` but does not count
   reschedules.
4. **Focus-session ergonomics:** Extra Time and Edit Focus Duration after
   the fact, retroactive "+ Add Record", and a note captured mid-session
   ([Pomodoro](https://help.ticktick.com/articles/7055782010496745472)).
5. **Completion rate = completed ÷ originally scheduled**, a measure of
   planning honesty
   ([statistics](https://help.ticktick.com/articles/7082302534169133056)).
6. **Timetable import by photo OCR or university portal**, in Dida365
   ([help](https://help.dida365.com/articles/6950372717036044288)). Typing
   in a class schedule by hand is the onboarding cost of Omakase's study
   side (`study/classschedules/`, API only today).
7. **An ICS feed out, per list**
   ([ICS](https://help.ticktick.com/articles/7055781574649839616)), the
   cheapest integration for a user who lives in another calendar. Omakase
   has promised .ics export only (docs/IDEA.md §18).

## 12. Weaknesses to avoid

1. **A task is its own time block.** Duration is a field on the task, so
   one task cannot be spread over several sessions without duplicating it
   (§2). Omakase's API models the block separately (`timeblocks/`, which
   point at a task or a study block).
2. **Platform feature drift.** The Mac lacks batch drag and Postpone, the
   mini calendar is Web and Windows only, white noise is missing on Web,
   the AI Assistant is missing on Windows, and summary insertion is
   mobile-only (§3-§5). Users notice (see
   [`issues-ticktick.md`](issues-ticktick.md), E).
3. **The timeboxing surface is paywalled.** Calendar views and duration
   tasks are Premium ([upgrade](https://ticktick.com/upgrade)), and reviews
   complain (`issues-ticktick.md`, B).
4. **No documented offline contract.** Users describe sync that needs a
   manual refresh (`issues-ticktick.md`, A).
5. **Study is a bolt-on in TickTick and a region-locked module in Dida365.**
   Nothing links courses to tasks or focus time (§6).
6. **Two overlapping scores** (achievement score and completion rate) and
   no daily close-out; reflection is left to AI prompts (§4, §7).

## 13. Bottom line (for a work+study planner)

TickTick is the broadest single overlap with what Omakase describes: tasks,
a calendar timeboxed by dragging, a pomodoro timer with statistics, habits,
cross-platform sync, a student discount, and a mature Google, CalDAV and
ICS story. It does not model study as a hierarchy: no semester, course or
study block in the international app. It has no class timetable behind
work blocks (Dida365 has one, region-locked and paid to show in the
calendar). It has no explicit plan → focus → review ritual with a daily
shutdown, and it documents no offline behaviour.

Those four gaps are where Omakase's design differs, but only one is
reachable by a user today. Omakase's API has the study hierarchy, the
timetable, pomodoro sessions and a daily review; its only client, the Mac
app, has sign-in and an offline-capable Today checklist. The daily loop is
planned (docs/ROADMAP.md M3) and the calendar with class occurrences behind
it is planned (M4). Against TickTick, Omakase lacks breadth that users
already have: recurrence, reminders, habits, calendar sync in and out,
import, mobile, and a public API or MCP server.

## 14. Sources

- https://help.ticktick.com/articles/7055782166172532736
- https://help.ticktick.com/articles/7054286604315131904
- https://help.ticktick.com/articles/7054327235582361600
- https://help.ticktick.com/articles/7055781980423585792
- https://help.ticktick.com/articles/7055782309420597248
- https://help.ticktick.com/articles/7055782219767349248
- https://help.ticktick.com/articles/7055782255804809216
- https://help.ticktick.com/articles/7055782240994721792
- https://help.ticktick.com/articles/7055780476358754304
- https://help.ticktick.com/articles/7055781896457814016
- https://help.ticktick.com/articles/7321455627362893824
- https://help.ticktick.com/articles/7055782408586526720
- https://help.ticktick.com/articles/7055782149730861056
- https://help.ticktick.com/articles/7399726920725692416
- https://help.ticktick.com/articles/7213444784319365120
- https://help.ticktick.com/articles/7055780375439605760
- https://help.ticktick.com/articles/7063851189372190720
- https://help.ticktick.com/articles/7358389904469917696
- https://help.ticktick.com/articles/7055782085826445312
- https://help.ticktick.com/articles/7401564165023727616
- https://help.ticktick.com/articles/7503016104470511616
- https://help.ticktick.com/articles/7475477082185662464
- https://help.ticktick.com/articles/7055792921664028672
- https://help.ticktick.com/articles/7055782128335716352
- https://help.ticktick.com/articles/7055782010496745472
- https://help.ticktick.com/articles/7055781994591944704
- https://help.ticktick.com/articles/7055781966800486400
- https://help.ticktick.com/articles/7082302534169133056
- https://help.ticktick.com/articles/7055781785312952320
- https://help.ticktick.com/articles/7375802644289290240
- https://help.ticktick.com/articles/7055781614550253568
- https://help.ticktick.com/articles/7055781593733922816
- https://help.ticktick.com/articles/7209482814528421888
- https://help.ticktick.com/articles/7055781574649839616
- https://help.ticktick.com/articles/7055781405648748544
- https://help.ticktick.com/articles/7263009660070789120
- https://help.ticktick.com/articles/7467494539406606336
- https://help.ticktick.com/articles/7055781495671095296
- https://help.ticktick.com/articles/7438129581631995904
- https://help.ticktick.com/articles/7465251130025443328
- https://help.dida365.com/articles/6950372717036044288
- https://blog.ticktick.com/2020/08/31/new-school-year-new-chapter/
- https://ticktick.com/about/features?language=en_US (marketing page)
- https://ticktick.com/about/download
- https://ticktick.com/upgrade
- https://www.ticktick.com/education
- https://developer.ticktick.com/docs#/openapi
- https://apps.apple.com/us/app/ticktick-to-do-list-calendar/id626144601
- https://apps.apple.com/us/app/ticktick-to-do-list-calendar/id966085870

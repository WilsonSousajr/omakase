# MyStudyLife - deep dive

> Captured **2026-09-25**, against `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **Read:** MyStudyLife's FAQ, plan, tour, about and guide pages, its App
> Store and Google Play listings and App Store version history, and Apple's
> public review feed for the app. For Power Planner, its support docs and
> app code on GitHub: `powerplanner/powerplannersupport` at `9762bf5` and
> `powerplanner/powerplannerapps` at `c22d20c` (the default branches' heads
> on the capture date). For Shovel, its App Store listing, pricing page and
> vendor blog.
>
> **Coverage limits.** MyStudyLife's help centre
> (`https://care.mystudylife.com/en/`) failed with a TLS handshake error
> from every client tried (WebFetch, curl, Python and Chrome), and its
> legacy Zendesk copies returned 403. **How MyStudyLife's timetable works is
> therefore taken only from its FAQ and marketing pages**, and is labelled
> as such. Search-engine snippets of the help articles are not used. No
> MyStudyLife changelog, roadmap or feedback board was found; the App Store
> version history stands in for a changelog. Shovel's help centre
> (`https://help.shovelapp.io/en`) has an expired certificate. Screens behind
> a MyStudyLife sign-in were not opened, and Reddit was blocked by the
> browser tool, so there is no Reddit user voice. A second check later the
> same day could not reach `mystudylife.com/faqs/` or `/msl-plus/` at all
> (no connection on port 443), so the FAQ quotes rest on the first read
> alone; the App Store figures were re-checked and matched.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

Labels: **(marketing page)** is a vendor landing page, not docs;
**vendor-self-reported** is a vendor's own number; **user voice** is a review
or issue, never proof of how a feature works. App Store reviews are cited by
store, date and title, because Apple's review feed has no per-review URL.

## 1. Purpose and target user

The App Store listing calls MyStudyLife the "#1 student planner" to
"organize classes, manage homework, track grades, and prepare for exams",
for high school with rotating schedules through university
([App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).
The About page names "students balancing employment and study" as a target
(marketing page, [about](https://mystudylife.com/about/)).

It claims 10M+ students in 187 countries (vendor-self-reported,
[home](https://mystudylife.com/)). Google Play shows 5M+ downloads, 3.8
stars and 59.4K reviews
([Play](https://play.google.com/store/apps/details?id=com.virblue.mystudylife&hl=en_US)).
The US App Store shows 4.5 from 6.2K ratings
([US listing](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)),
the GB store 4.4 from 873
([GB listing](https://apps.apple.com/gb/app/my-study-life-school-planner/id910639339)).
A parent product, Family Connect, gives parents a live view of a child's
schedule, homework, exams and grade alerts (marketing page,
[parent](https://mystudylife.com/parent/)).

## 2. Data model

- **Subjects and classes.** "The color of a class is set by its subject"
  ([FAQ](https://mystudylife.com/faqs/)). Subjects are colour-coded with
  bulk add on the free tier ([MSL+](https://mystudylife.com/msl-plus/)).
  Subjects come from a fixed list; a developer reply to a review says
  "custom subjects are still an option" (App Store US, "Downhill plummet",
  2024-08-20). Many reviewers could not find them (see
  [`issues-mystudylife.md`](issues-mystudylife.md)).
- **Rotations.** "When you configure a week rotation schedule and add/edit
  classes, you will get the option to choose which week (eg. 'Week 2') as
  well as 'Every Week'" ([FAQ](https://mystudylife.com/faqs/)). The free
  tier lists "weekly, rotating, week A/B, block and custom schedules"
  ([MSL+](https://mystudylife.com/msl-plus/)). Day rotation (Day A/B)
  appears only in marketing ([tour](https://mystudylife.com/tour/)). The
  number of rotation weeks and how day rotation works could not be
  verified, because the help centre was down.
- **Terms and holidays.** "Holiday and term date input with automatic class
  pausing" (marketing page, [tour](https://mystudylife.com/tour/)). The FAQ
  gives the modelling trick: "to cancel classes during exam week you can
  simply create a holiday named Exam Week"
  ([FAQ](https://mystudylife.com/faqs/)). So a holiday is a date range that
  suppresses repeating classes. Classes have start and end dates (marketing
  page, [tour](https://mystudylife.com/tour/)). The 2025 onboarding is "a
  guided setup based on your schedule type and term dates" (version 8.0.0
  notes, [App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).
- **Tasks.** A task belongs to a subject, with a due date, a tick-off and an
  optional duration ("Essay, due Thursday, three hours")
  ([assignment tracker guide](https://mystudylife.com/assignment-tracker-guide/),
  dated 2026-09-21). Partial progress ("how much of a task has been
  completed"), subtasks, auto-repeat and task categories (essay, group
  project, reading, revision) are on a marketing page, which also says
  revision tasks can be assigned to an exam
  ([tour/tasks](https://mystudylife.com/tour/tasks)).
- **Exams** are their own entity: date, time, room and seat, countdowns,
  and conflict detection with classes
  ([MSL+](https://mystudylife.com/msl-plus/); marketing,
  [tour](https://mystudylife.com/tour/)).
- **Xtra / Activities**: clubs, sports, "shifts" and appointments, MSL+ only
  ([MSL+](https://mystudylife.com/msl-plus/)). The App Store lists
  "part-time jobs" under Xtra Planner.
- **Grades**: a score per exam, GPA or average, and a per-subject breakdown
  (marketing page, [tour](https://mystudylife.com/tour/)).

## 3. Planning surface

MyStudyLife is a due-date and timetable planner. Its calendar shows
classes, homework and exams together
([MSL+](https://mystudylife.com/msl-plus/)). The task guide describes
durations but says nothing about placing a work session on the calendar
([guide](https://mystudylife.com/assignment-tracker-guide/)).

The nearest thing to scheduled study is Scout AI drafting "revision plans"
that break "big exams into focused study sessions around your life"
(marketing page, [tour/tasks](https://mystudylife.com/tour/tasks)), and the
App Store's "Spread your study sessions over time". How those sessions land
on the calendar could not be verified.

User voice: after v2, tasks "show up on the calendar like classes, making
it really difficult to tell what's actually a class and what's a homework
assignment" (App Store US, "Downhill plummet", 2024-08-20).

## 4. Daily ritual

A dashboard shows "next classes, upcoming assignments, and activities";
customising it is MSL+ (marketing page,
[tour](https://mystudylife.com/tour/)). Reminders fire before classes,
exams and deadlines, for incomplete tasks and for activities (same page),
with user-set lead times such as the "evening before a deadline"
([guide](https://mystudylife.com/assignment-tracker-guide/)).

No end-of-day review or shutdown appears on any page opened. Scout offers
"weekly overview queries" (marketing page,
[tour](https://mystudylife.com/tour/)).

## 5. Focus

A Pomodoro "Focus timer" can be linked to a task, with "streaks &
sessions" (marketing page, [tour/tasks](https://mystudylife.com/tour/tasks)).
It arrived in the August 2024 v2 redesign with stats, widgets and dark mode
([introducing MSL](https://mystudylife.com/introducing-msl/), 2024-08-26).
The plan page does not say whether it is free or MSL+.

## 6. Study features

- Grades: exam scores, GPA and a target GPA (App Store description;
  [tour](https://mystudylife.com/tour/)). User voice: a paying user found no
  grade tracking (App Store US, "No grade tracking", 2025-06-11, 1 star).
- Streaks exist as gamification
  ([tour/tasks](https://mystudylife.com/tour/tasks)); a reviewer called "the
  new streak feature" unnecessary (App Store US, "Please stop changing the
  app", 2024-09-22). No XP was found.
- Attendance was not found on any page opened, so it is unverified either
  way.

## 7. Analytics

"Enhanced stat tracking and analytics" arrived with v2
([introducing MSL](https://mystudylife.com/introducing-msl/)), and there is
a per-subject grade breakdown (marketing page,
[tour](https://mystudylife.com/tour/)). No time-spent analytics are
documented on any page opened.

## 8. Platforms, native or not, offline

- iPhone, iPad (iOS/iPadOS 17+) and Apple Vision. There is **no Mac
  listing**: the compatibility block names only those three
  ([App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).
  Android on [Google Play](https://play.google.com/store/apps/details?id=com.virblue.mystudylife&hl=en_US),
  and a web app at https://web.mystudylife.com/. Desktop means the web app.
- Offline is claimed: "Offline functionality" (marketing page,
  [tour](https://mystudylife.com/tour/)) and "online or offline"
  ([class planner page](https://mystudylife.com/class-planner-and-schedule-organizer/)).
  An FAQ testimonial calls "the offline mode … invaluable"
  ([FAQ](https://mystudylife.com/faqs/)). How offline edits reconcile is
  unverified.
- **The v2 migration broke sync.** In 2024 old accounts had to be recreated
  and the v1 web and v2 mobile apps did not sync with each other (App Store
  US: "Why did you erase old accounts…" 2024-09-04, "THE BROKE THE SYNC
  FEATURE" 2024-10-01, "why the update?" 2024-10-05: "app doesn't sync
  unless both platforms using the same version"). The v1 web app was later
  taken down ("old web version gone", 2025-08-09). All user voice.
- **Time-zone bugs are acknowledged by the vendor**: versions 7.3.4 and
  7.3.5 (February 2025) "resolved various time zone related bugs" (App
  Store version history,
  [listing](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).

## 9. Pricing and student plans

- **Free**: timetable (all schedule types), calendar, homework and revision
  **limited to 5 tasks at a time**, exams, subjects, the first AI timetable
  scan, all devices ([MSL+](https://mystudylife.com/msl-plus/)).
- **MSL+** adds unlimited tasks, subtasks, repeating tasks, unlimited Scout
  AI, Calendar Sync (Google, Apple, school calendars), Activities (clubs,
  sports, shifts), all task and exam types, and customisation, with a 7-day
  trial ([MSL+](https://mystudylife.com/msl-plus/)).
- Prices: MSL+ **$6.99/month or $39.99/year**. Family Connect is
  $9.99-$19.99/month or $59.99-$119.99/year for 1 to 5 students. The
  in-app purchase list also shows "MSL Premium – Weekly $2.99"
  ([App Store](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339)).

The product is itself the student plan; no separate discount applies.

## 10. Integrations

Calendar sync to Google, Apple and school calendars, on MSL+
([MSL+](https://mystudylife.com/msl-plus/)). The homepage also names
Outlook, iCal, Blackboard and Canvas (marketing page,
[home](https://mystudylife.com/)), and the App Store lists "iCal calendar
synchronization". Photo import of a timetable is "Schedule Scan" / Scout.
Whether sync imports, exports or both, and how the LMS links work, is
unverified. User voice: CSV import broke in v2 (App Store US, "Don't use
this anymore" 2024-09-30; "Went from awesome to unusable" 2024-10-01).

## 11. Strengths worth borrowing

1. **Rotation is a property of the schedule, not of each class.** The
   schedule is fixed or rotating, then each class time picks "Week N" or
   "Every Week" ([FAQ](https://mystudylife.com/faqs/)). Power Planner does
   the same with Week A/B plus settings for the "current week" and the day
   the week changes
   (`src/content/docs/schedule/week-a-b-schedules.md` in
   `powerplanner/powerplannersupport`). Omakase's `ClassSchedule` has only
   `day_of_week`, so rotation is absent (`backend/study/models.py`).
2. **Holidays suppress repeating classes.** A named holiday ("Exam Week")
   as a cancellation device is cheap and legible to the user
   ([FAQ](https://mystudylife.com/faqs/); Power Planner
   `src/content/docs/schedule/holidays.md`: multi-day, with start and end).
   Omakase computes occurrences per request from `ClassSchedule` inside the
   semester's dates and stores none (`docs/ARCHITECTURE.md`), so a holiday
   range could be applied at expansion time. Holidays and cancelled
   occurrences are promised only (docs/IDEA.md §3).
3. **Per-class start and end dates** inside a term (marketing,
   [tour](https://mystudylife.com/tour/); Power Planner
   `src/content/docs/classes/partial-semester-class.md`) cover a module that
   ends mid-semester.
4. **Several time slots per class**, such as a lecture on Monday and
   Wednesday plus a lab on Thursday (Power Planner
   `src/content/docs/schedule/adding-schedule.md`,
   `adding-other-times.md`).
5. **Exams as first-class dated items** with room, seat and countdown, and
   revision tasks linked to the exam
   ([MSL+](https://mystudylife.com/msl-plus/),
   [tour/tasks](https://mystudylife.com/tour/tasks)).
6. **Partial progress** on a task instead of a binary done
   ([tour/tasks](https://mystudylife.com/tour/tasks)). Power Planner users
   praise the same (App Store PP review, 2024-11-01).

## 12. Weaknesses to avoid

- **A big-bang rewrite that forced account recreation and broke web and
  mobile sync** (§8). This is the dominant theme: 98 of the 150 most recent
  US App Store reviews are 1-star
  ([review feed, pages 1-3](https://itunes.apple.com/us/rss/customerreviews/page=1/id=910639339/sortby=mostrecent/json),
  2024-08-27 to 2026-09-10).
- **Wall-clock class times that drift** by hours after DST, a timezone
  change, or at random (see the mining file). The vendor shipped timezone
  fixes twice (versions 7.3.4 and 7.3.5).
- **Paywalling basic list-keeping**: a 5-task cap on the free tier
  ([MSL+](https://mystudylife.com/msl-plus/)).
- **A fixed subject list** that does not fit college courses (§2, and
  `issues-mystudylife.md`, E).
- **Tasks drawn like classes** on the calendar, with no list of what is due
  (§3, and `issues-mystudylife.md`, G).
- **No native desktop app.** Desktop is the web app, which a reviewer says
  shows about 2 hours of the day in the calendar (App Store GB, 2024-06-10).

## 13. Bottom line (for a work+study planner)

MyStudyLife does not treat a student's work as a hierarchy. Its answer is
Xtra / Activities (clubs, sports, "shifts", part-time jobs), which is paid
([MSL+](https://mystudylife.com/msl-plus/)). Those are calendar
commitments, not projects with tasks, even though the About page names
"balancing employment and study" as a target (marketing page).

It is the reference for timetable modelling: rotations as a schedule
property, holidays that pause classes, exams as dated items. It plans due
dates, not hours. Its 2024 rewrite shows the cost, in reviews, of forcing
users to re-sign-up and of leaving two app generations that cannot sync
(§8, §12) - a risk for any native client that ships on its own release
schedule.

## Power Planner and Shovel

The two secondary student planners, kept brief.

### Power Planner (BareBones Dev, LLC)

- **Signal.** App Store US: 4.8 from 1.7K ratings
  ([App Store](https://apps.apple.com/us/app/power-planner-homework-more/id1278178608)).
  Of the 100 most recent US reviews, 79 are 5-star and 3 are 1-star
  ([review feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1278178608/sortby=mostrecent/json),
  pages 1-2, 2022-09-07 to 2026-09-20). Several reviewers say they left
  MyStudyLife for it after the 2024 update (PP reviews "Planning App
  Convert" 2024-08-20, 2024-09-05, 2024-10-24; the MSL review "Downhill
  plummet" names Power Planner).
- **Open source.** The apps are GPL-3.0, 47 stars, last push 2026-09-13
  (`gh api repos/powerplanner/powerplannerapps`). The support docs are on
  GitHub too (`powerplanner/powerplannersupport`). It is one developer:
  "It's just me … it might take several days"
  (`src/content/docs/faq/contact-support.md`).
- **Platforms.** iOS/iPadOS, Android/Chromebook, Windows, Mac (the App
  Store lists macOS 12+), and web in beta
  (`src/content/docs/faq/platforms.md`). The code is C# on Xamarin and UWP
  over a shared data library "which does all of the syncing, storage"
  (repo README). Offline accounts exist: an `IsOnlineAccount` flag, and the
  README says "offline accounts should work" without a server. Settings
  changed offline are synced later (`NeedsToSyncSettings`), and the account
  has a school time zone (`SetSchoolTimeZone`), both in
  `PowerPlannerAppDataLibrary/DataLayer/AccountDataItem.cs`.
- **Model.** Years → Semesters (start and end dates) → Classes. Classes can
  be partial-semester, have several time slots, and alternate Week A/B.
  There are multi-day holidays, tasks and events, checklists (since
  v2605.11), and weighted grades, GPA, credits, pass/fail and extra credit
  (support docs: `years-and-semesters/*.md`, `schedule/*.md`,
  `grades/*.md`, `tasks-and-events/checklists.md`).
- **Daily ritual.** An automatic "day before" reminder "sent 10 minutes
  after your last class, or at 3 PM", plus a "day of" reminder an hour
  before the due time (`tasks-and-events/automatic-reminders.md`). Tying the
  reminder to the end of the class day is worth borrowing.
- **Focus: none.** Issue #61, "Add timer, stopwatch and progress bar for
  tasks", has been open since 2021-03-01
  ([#61](https://github.com/powerplanner/powerplannerapps/issues/61)).
- **Pricing.** Free with limits (1 semester, 5 grades per class, 1
  repeating bulk entry, 1 photo per item). Premium is a **$4.99 one-time
  lifetime purchase**, shared across platforms
  (`src/content/docs/faq/premium-version.md`; App Store IAP "Premium
  (Lifetime) $4.99").
- **Integrations.** Google Calendar
  (`PowerPlannerAppDataLibrary/ViewModels/MainWindow/Settings/GoogleCalendarIntegrationViewModel.cs`).
- **Timebox or due date?** Due date. Tasks carry a due time and a "Before
  class" option; issue #48 reports it attaching to the wrong class
  ([#48](https://github.com/powerplanner/powerplannerapps/issues/48)). No
  study-time blocks.

### Shovel (How To Study Smart, LLC)

- **Signal.** App Store US: 4.2 from 233 ratings, "Designed for iPad. Not
  verified for macOS", and a "companion app" that "Requires account setup
  on our web platform"
  ([App Store](https://apps.apple.com/us/app/shovel-study-planner/id1467742357)).
  Of the 52 most recent US reviews, 21 are 5-star and 11 are 1-star
  ([review feed](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1467742357/sortby=mostrecent/json)).
  The web app is at https://dig.shovelapp.io, linked from
  [shovelapp.io](https://shovelapp.io).
- **The only one that timeboxes study** (App Store description): "Plan
  exactly WHAT task you will work on, WHEN, and for HOW LONG"; "Assign
  tasks to specific study times"; "See which tasks you haven't planned or
  how much of a task you haven't planned yet". **Time Cushion** is available
  study time minus time needed, "continuously in REAL-TIME". Reading time
  is estimated from pages and reading speed (also on the vendor blog,
  marketing,
  [blog](https://shovelapp.io/blog/shovel-the-only-study-planner-that-creates-actionable-study-plans-from-canvas-brightspace-moodle-and-google-classroom/)).
  "Your ideal schedule" blocks out busy time and "Me-Time"; a timeline shows
  "Unplanned Study Times" against "Planned Study Times"; rotating events
  repeat "every XX weeks"; a built-in timer tracks time per task; grades
  are weighted.
- **Integrations.** Canvas, Brightspace, Moodle and Google Classroom, plus
  PDF syllabi (marketing, [shovelapp.io](https://shovelapp.io) and the blog
  above). Sync mechanics are unverified.
- **Pricing.** $9.79/month or $39/year with a 7-day trial
  ([pricing](https://shovelapp.io/pricing/)). The App Store IAPs show
  "Lifetime plan $46.99 / $13.99". The two sources disagree, so both are
  given.
- **Weakness.** The mobile app is a weak companion: blank white screens,
  crashes, "The app is dead" (user voice, reviews 2022-01-23, 2023-04-12,
  2024-10-14, 2024-11-28, 2026-01-23). A 2025-08-20 review asks to "put this
  app back in development". No native Mac app.
- **Work.** Shovel models "weekly commitments" and "Activities, Meals, Me
  Time" as time not available for study (App Store description). A "grad
  student with a full time job" and a professor who models "research, grant
  proposals" as fake classes use it (user voice, reviews 2023-05-15 and
  2020-10-20). Work is capacity that gets subtracted, not something planned.

### Across the three

None gives work its own projects and tasks, planned into the same time
blocks as study. Users bend classes into work containers: the Shovel
professor above, and Power Planner issue #117, which asks for "a separate
'tasks' category in place of classes" so that work tasks survive across
semesters ([#117](https://github.com/powerplanner/powerplannerapps/issues/117),
open since 2022-12-20). Issue #131 asks for a to-do app integration
([#131](https://github.com/powerplanner/powerplannerapps/issues/131)). That
gap is the one Omakase's API is built around (workspaces → projects → tasks
beside semesters → disciplines); no Omakase client can plan it yet.

## 14. Sources

- https://mystudylife.com/
- https://mystudylife.com/about/
- https://mystudylife.com/faqs/
- https://mystudylife.com/msl-plus/
- https://mystudylife.com/tour/
- https://mystudylife.com/tour/tasks
- https://mystudylife.com/parent/
- https://mystudylife.com/assignment-tracker-guide/
- https://mystudylife.com/introducing-msl/
- https://mystudylife.com/class-planner-and-schedule-organizer/
- https://web.mystudylife.com/
- https://apps.apple.com/us/app/my-study-life-school-planner/id910639339
- https://apps.apple.com/gb/app/my-study-life-school-planner/id910639339
- https://play.google.com/store/apps/details?id=com.virblue.mystudylife&hl=en_US
- https://itunes.apple.com/us/rss/customerreviews/page=1/id=910639339/sortby=mostrecent/json (pages 1-3)
- https://care.mystudylife.com/en/ (failed: TLS handshake)
- https://apps.apple.com/us/app/power-planner-homework-more/id1278178608
- https://itunes.apple.com/us/rss/customerreviews/page=1/id=1278178608/sortby=mostrecent/json (pages 1-2)
- https://github.com/powerplanner/powerplannerapps (at `c22d20c`), issues #48, #61, #117, #131
- https://github.com/powerplanner/powerplannersupport (at `9762bf5`)
- https://apps.apple.com/us/app/shovel-study-planner/id1467742357
- https://itunes.apple.com/us/rss/customerreviews/page=1/id=1467742357/sortby=mostrecent/json
- https://shovelapp.io
- https://shovelapp.io/pricing/
- https://shovelapp.io/blog/shovel-the-only-study-planner-that-creates-actionable-study-plans-from-canvas-brightspace-moodle-and-google-classroom/
- https://help.shovelapp.io/en (failed: certificate expired)

# Motion - deep dive

> Captured **2026-09-25**, against `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **Read:** Motion's help centre (a GitBook site, read through the Markdown
> version of each page and the index at
> https://www.usemotion.com/help/llms.txt), its pricing page (including the
> page's embedded `__ssr_data__` JSON), download page, homepage, a funding
> post, the iOS App Store listing and review feed, and the contents of the
> Mac release archive. GitBook's generated `?ask=` answers are not cited.
> For Reclaim.ai, its Intercom help centre (index at
> https://help.reclaim.ai/llms.txt, articles read as `.md`), pricing page
> and public roadmap.
>
> **Coverage limits.** Motion has no public changelog or roadmap. The Mac
> App Store listing was not opened separately. No help page documents the
> time tracker or any offline mode. Reddit refused scripted access, and no
> G2 or Capterra reviews were read.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

Labels: **(marketing page)** is a landing page, not docs;
**vendor-self-reported** is a vendor's own number; **user voice** is App
Store, Trustpilot or forum content, never proof of how a feature works.

## 1. Purpose and target user

The help centre's framing: "Motion is an all-in-one work platform built
around automatic scheduling. It continuously plans your day by deciding
what you should work on and when ... your schedule is always up to date,
without manual planning", and "Motion plans your day for you"
([readme](https://www.usemotion.com/help/readme.md)). The audience runs
"from individuals to large teams", split into Individuals, Teams and
Companies, with most of the content under Teams and Companies
([what is Motion](https://www.usemotion.com/help/getting-started/what-is-motion.md)).

**It is repositioning toward businesses and agents.** A funding post dated
8 September 2025 says "Motion is building the first end-to-end agentic
work suite - from sales and marketing to project management", focused on
"small and mid-sized businesses", and that AI Employees went "from $0 to
8-figure ARR" in three months. It reports $60M raised at a $550M
valuation, "mid-8-figure ARR" and "10,000+ B2B customers", all
vendor-self-reported
([funding post](https://www.usemotion.com/blog/motion-raises-60m-to-build-the-agentic-work-suite-for-businesses)).
The docs still place "AI Employees" in Workspaces
([what is Motion](https://www.usemotion.com/help/getting-started/what-is-motion.md)).

Observed on the capture date: `https://www.usemotion.com/ai-employees/ai-sdr`
redirects (301) to `/`, and the homepage no longer names AI Employees. Its
headline is "Get an unfair advantage by using AI to double productivity",
with modules from "AI Project Manager" to "AI Workflows" and the claim
"Over 1 million top performers and teams trust Motion" (vendor-self-reported,
marketing page, [home](https://www.usemotion.com/)). Whether the AI
Employees line was retired could not be verified. Students are not
mentioned on the homepage, the pricing page or in the help centre.

## 2. Data model

- **Workspace → Folder → Project → Task**, with Docs at any level. "Task:
  The atomic unit of work. A task has an assignee, due date, and status."
  Status, priority, labels, custom fields and dependencies cut across every
  level ([definitions](https://www.usemotion.com/help/knowledge-management/data-hierarchy/reference-data-hierarchy/definitions.md)).
- Projects are "regular (ad hoc) or workflow-based (with reusable templates
  and stages)"
  ([what is Motion](https://www.usemotion.com/help/getting-started/what-is-motion.md)).
  Tasks in a stage not yet active show as Ghost placeholders
  ([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)).
- Scheduling inputs on a task: start date, duration, deadline, priority
  (ASAP is the top tier), chunking, the schedule it belongs to (work hours
  and breaks), recurrence, and blockers
  ([what auto-scheduling considers](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/what-auto-scheduling-considers.md),
  [task scheduling FAQ](https://www.usemotion.com/help/project-management/task/task-scheduling-faq.md)).
- **Hard deadline**: "Motion prioritizes completing the task on time, even
  if it means scheduling it outside your normal working hours" (FAQ).
- **Task vs Event.** Events are "Fixed-time commitments ... static and never
  auto-scheduled"
  ([what is Motion](https://www.usemotion.com/help/getting-started/what-is-motion.md)).
  "Events always take precedence over tasks"
  ([fixed commitments](https://www.usemotion.com/help/project-management/meeting-events/reference-meeting-events/fixed-commitments.md)).
- **Auto-scheduled vs fixed.** A task dragged onto the calendar becomes a
  fixed task that "the system won't automatically move ... unless you
  manually reschedule"
  ([manual vs auto](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/manual-vs-auto-scheduling.md)),
  with the caveat in §3. With the per-task Auto-schedule toggle off, the
  task "won't get scheduled nor appear on your calendar" and shows "No ETA"
  ([how-to](https://www.usemotion.com/help/time-management/auto-scheduling/auto-scheduling-how-to-guide.md),
  as summarised by WebFetch).
- Task states: On time, Actively working, Past due, Can't fit, Ghost,
  Locked. Task types: Siri/Email, Recurring, Chunked, Regular, Reminder; a
  Reminder is a task of 4 minutes or less, pinned at the top and never
  placed on the calendar
  ([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)).

## 3. Planning surface

- **Inputs, logic, output**: task parameters and user schedules in, an
  "optimization engine scanning for open time blocks", "scheduled calendar
  blocks with ETAs" out. Deadlines and priority come first, and the engine
  "respects breaks, working schedules, and external events"
  ([behind the scenes](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/how-auto-scheduling-works-behind-the-scenes.md)).
- **When it reruns**: on change. "Tasks reschedule automatically if new
  meetings or conflicts arise"; "External calendar conflicts always
  override task blocks"; "Higher-priority or sooner-deadline tasks across
  projects are given scheduling precedence" (same page). An edit in the AI
  Agenda triggers it too: "The moment you edit a task, Motion recalculates
  your schedule" ([AI Agenda](https://www.usemotion.com/help/time-management/ai-agenda.md)).
- **What it rearranges**: every auto-scheduled task that is not locked,
  around busy events treated as "fixed anchors"
  ([what is Motion](https://www.usemotion.com/help/getting-started/what-is-motion.md)).
  "Long tasks are split into smaller blocks, but splits respect a minimum
  block size" (behind-the-scenes page).
- **A lock expires.** Dragging a task locks it, but "Motion's algorithm
  will only reschedule these tasks if they aren't completed within 60
  minutes of their scheduled time slot". The page's own example: a task
  moved by hand to 1 PM was rescheduled "because it wasn't marked as
  completed within the set timeframe"
  ([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)).
  The only ways to keep something still are to turn auto-scheduling off
  (which takes it off the calendar) or to make it an Event; for a fixed
  lunch the FAQ says "create a recurring event (not a task)"
  ([FAQ](https://www.usemotion.com/help/project-management/task/task-scheduling-faq.md)).
- **The docs argue against manual scheduling**, calling it "Static",
  "Time-consuming", "Less predictive" and "Error-prone"
  ([manual vs auto](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/manual-vs-auto-scheduling.md)).
  "Too much manual override → Pinning or fixing tasks reduces flexibility"
  is listed as a pitfall, and Motion "prompts you to free up flexibility if
  the plan becomes too rigid"
  ([best practices](https://www.usemotion.com/help/time-management/auto-scheduling/concept-auto-scheduling/best-practices.md)).
  It is the opposite of Omakase's design, where a time block has a
  user-set start and end (`timeblocks/`).
- **Overdue tasks**: "Motion reschedules the task into the next available
  slot" (behind-the-scenes page). Past due covers both a passed deadline
  and a task "scheduled for a time slot beyond their original deadline in
  the future", so it is a forecast as well as a record (task-states page).
  The AI Agenda's past-due list offers **Do ASAP**, **Extend deadline** or
  **Ignore warning**, and warns that "until cleared, overdue tasks will
  block your schedule and throw off prioritization"
  ([AI Agenda how-to](https://www.usemotion.com/help/time-management/ai-agenda/ai-agenda-how-to-guide.md)).
- **Impossible deadlines** become Can't fit: no feasible slot "for the next
  31 days (or 92 days for Motion teams)", pinned at the top with ❗
  (task-states page). "The task remains unscheduled until you adjust its
  parameters" (behind-the-scenes page).
- **A missed recurring instance** is not rescheduled: it is overdue, and
  the next one appears on the original schedule (FAQ).
- **Calendar sync**: events sync both ways; tasks sync one way. "You drag
  the task block in Outlook to Wednesday morning. Motion does not change."
  iCloud gets no task sync
  ([sync models](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/scheduling-models-uni-and-bi-directional-sync.md)).

## 4. Daily ritual

The AI Agenda is "your daily control center": today's tasks and meetings,
complete, edit and reschedule, a document-like editor with inline `/task`,
and a sidebar badge counting past-due tasks
([AI Agenda](https://www.usemotion.com/help/time-management/ai-agenda.md)).
Its model: "Today is precise ... The future is flexible ... Everything
adapts" ([purpose](https://www.usemotion.com/help/time-management/ai-agenda/concept-ai-agenda/purpose.md)).
"Motion automatically saves daily agendas", one per day, in month folders
([AI Agenda how-to](https://www.usemotion.com/help/time-management/ai-agenda/ai-agenda-how-to-guide.md)).

No morning plan or shutdown is documented. "Start your day here: Review
upcoming tasks before jumping into meetings" is advice, not a guided flow
(AI Agenda page). There is no reflection, rating or rollover step.

## 5. Focus

No pomodoro or focus timer appears in the help index
([llms.txt](https://www.usemotion.com/help/llms.txt)). "Time Tracking" is a
Business AI feature ([pricing](https://www.usemotion.com/pricing)), and the
Chunked task type mentions "the time tracker" (task-states page), but no
help article describes the tracker, so how it works is unverified. Break
rules exist ("Break between tasks",
[best practices](https://www.usemotion.com/help/time-management/auto-scheduling/concept-auto-scheduling/best-practices.md)).

## 6. Study features

None. No semester, course, class timetable, exam or spaced-repetition
concept appears in the help index
([llms.txt](https://www.usemotion.com/help/llms.txt)). Going by the Event
definition in §2, a student's classes could only be recurring Events and
coursework tasks with deadlines.

## 7. Analytics

- **Dashboards** of number, bar, pie and line cards over Tasks or Projects,
  Y as Count or Total Hours, X as any field including ETA, shareable with a
  team ([dashboards](https://www.usemotion.com/help/project-management/dashboards/reference-dashboards.md)).
  "Advanced Dashboards & Reports" is Business AI
  ([pricing](https://www.usemotion.com/pricing)).
- **Capacity Planning** (Business AI): start from work hours, subtract
  calendar events ("All-day events count as 8 hours (not 24)"), subtract
  "only the unfinished portion of auto-scheduled tasks", and flatten
  overlapping events so two meetings at once count once, over 7 to 90 days
  ([capacity planning](https://www.usemotion.com/help/project-management/capacity-planning.md)).
- **Project status icons**: On Track, Missed Deadline, Scheduled Past
  Deadline, Stage Missed Deadline
  ([status indicators](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/status-indicators.md)).
- No personal reflection analytics (planned against done, focus time,
  streaks) appear in the help index.

## 8. Platforms, native or not, offline

- macOS, Windows, iOS, Android and web. The Mac app is a direct download
  (Apple silicon and Intel, macOS 11 or later) and is in the Mac App Store
  ([download](https://www.usemotion.com/download)).
- **The desktop app is Electron.** The download page links to
  `github.com/usemotion/desktopapp/releases/download/0.117.0/motion-0.117.0-mac-aarch64.zip`;
  the zip contains `Motion.app/Contents/Frameworks/Electron Framework.framework/`,
  `Squirrel.framework`, `Sparkle.framework` and "Motion Helper (Renderer)"
  and "(GPU)" helper apps. The latest release, 0.117.0, is dated 2025-12-15
  ([desktopapp](https://github.com/usemotion/desktopapp)).
- Desktop Tabs (up to 10, with sleep mode) carry a warning: "Refreshing
  your desktop app without saving your work in a dormant tab can cause data
  loss" ([desktop tabs](https://www.usemotion.com/help/getting-started/display-options/motion-desktop-tabs.md)).
- **Mobile is a companion**, "still quite a bit behind ... in terms of
  overall functionality"; workflow templates, saved views, bulk edit,
  workspace settings and Gantt are desktop-only
  ([mobile app](https://www.usemotion.com/help/getting-started/mobile-app/reference-mobile-app.md)).
- **iOS**: 4.1 from 1.9K ratings, iPhone and Vision only (no iPad build).
  Version 2.224.1 is dated 2025-11-27, and reviews through 2026-09-23 still
  carry that version, so there has been no iOS update in about 10 months.
  In-app purchases: "$44.99" monthly, "$294.99" annual
  ([App Store](https://apps.apple.com/us/app/motion-tasks-ai-scheduling/id1580440623),
  [review feed](https://itunes.apple.com/us/rss/customerreviews/id=1580440623/sortBy=mostRecent/json)).
- **Offline is not documented** anywhere in the help centre.

## 9. Pricing and student plans

From the pricing page's embedded JSON, per seat per month
([pricing](https://www.usemotion.com/pricing)):

| Plan | Team, annual | Team, monthly | Individual, annual | Individual, monthly | AI credits |
|---|---|---|---|---|---|
| Pro AI | $19 | $29 | $29 | $49 | 7,500/seat/mo, extra at 25¢ per 100 |
| Business AI | $29 | $49 | $39 | $69 | 15,000/seat/mo, extra at 19¢ per 100 |

Business AI adds Team Capacity Planning, Advanced Dashboards & Reports,
Timeline & Gantt, Time Tracking, Permissions, Central Billing and Priority
Support. The grid shows the $19 team price by default; a solo user pays
$29 to $69 a month.

- **Trial**: "Start your free trial. Risk free. Cancel anytime", with no
  length given on the page. App Store reviewers describe a 7-day trial
  (user voice, [review feed](https://itunes.apple.com/us/rss/customerreviews/id=1580440623/sortBy=mostRecent/json)).
  The help centre mentions an "Individual or Team Trial"
  ([account FAQ](https://www.usemotion.com/help/getting-started/faq/account-and-login-faq.md)).
- **Refunds**: "Canceling your subscription does not automatically trigger
  a refund"; cancelling needs the desktop or web app, or Apple
  Subscriptions for an in-app purchase
  ([cancel](https://www.usemotion.com/help/motion-support/cancel-your-plan.md)).
- **Student discount: none found**, on the pricing page or in the help
  centre; `/education` and `/students` return 404.
- Billing is per workspace
  ([billing](https://www.usemotion.com/help/project-management/workspaces/reference-workspaces/billing-and-plans.md)).

## 10. Integrations

- Google, Microsoft (O365/Exchange Online) and iCloud calendars, iCloud
  "more basic"
  ([providers](https://www.usemotion.com/help/time-management/all-things-calendars/reference-all-things-calendars/supported-providers.md)).
- Email-to-task at `tasks@usemotion.com`, which parses date and priority,
  and Siri Shortcuts
  ([native integrations](https://www.usemotion.com/help/settings/integrations/reference-integrations/native-integrations.md)).
- Zapier and a public API
  ([integrations](https://www.usemotion.com/help/settings/integrations.md)).
  "Currently, there are no plans for native integrations with third-party
  apps like Notion, ClickUp, or Google Sheets"
  ([integrations FAQ](https://www.usemotion.com/help/settings/integrations/integrations-faq.md)).
- AI Notetaker for Zoom, Meet and Teams, and booking links
  ([llms.txt](https://www.usemotion.com/help/llms.txt)).

## 11. Strengths worth borrowing

Without adopting automatic placement:

1. **A deadline-risk ETA.** Each task shows an ETA and acts as a "beacon"
   when it will miss its deadline (behind-the-scenes page). Omakase could
   compute a warning from blocks the user placed: the last block for a task
   falls after its `due_date`, or the planned minutes are fewer than
   `estimated_minutes`.
2. **"Scheduled past deadline" as its own state**, separate from overdue
   (task-states and status-indicators pages). It catches a bad plan before
   the date passes.
3. **Capacity arithmetic**: hours minus events minus unfinished task time,
   overlaps flattened, all-day events capped (capacity-planning page). For
   Omakase, a day's available hours minus class occurrences, compared with
   the estimates of the blocks placed. A workload check is promised only
   (docs/IDEA.md §6).
4. **Explicit verbs for past-due items**: Do ASAP, Extend deadline, Ignore
   warning (AI Agenda how-to). Omakase's rollover decisions in the daily
   review are promised in docs/IDEA.md §8 and planned for M3.
5. **A saved agenda per day** (AI Agenda how-to), an archive of each day's
   plan.
6. **Chunking with a minimum block size** (behind-the-scenes page).
7. **Reminders as tasks of 4 minutes or less** that are never time-blocked
   (task-states page).
8. **Email-to-task capture** (native-integrations page).

## 12. Weaknesses to avoid

1. **A lock is not a lock.** It expires if the task is not done within 60
   minutes of its slot (task-states page).
2. **The docs frame manual control as the error case** ("Error-prone";
   "Too much manual override" as a pitfall).
3. **The plan reflows on every edit or new meeting** (behind-the-scenes and
   AI Agenda pages).
4. **Stale overdue items "block your schedule"** until triaged (AI Agenda
   how-to), so the system degrades when the user is behind.
5. **Tasks sync one way** to Google or Outlook; a task moved there is
   ignored (sync-models page).
6. **Electron on the desktop, a mobile app "quite a bit behind", no iOS
   update in about 10 months, no iPad build, no documented offline mode**
   (§8).
7. **Price and billing friction**: $49/month for a solo user on monthly Pro
   AI, a credit meter, no student price, no automatic refunds, and
   cancellation that needs the desktop or web app (§9).
8. **Scope drift**: docs, notetaker, dashboards, workflow templates,
   credits and AI employees, away from the individual planner (§1).

## 13. Bottom line (for a work+study planner)

Motion treats planning as overhead to remove ("without manual planning").
It answers change by reflowing the calendar and overload with a ❗ and a
Can't-fit tray. The price is that the user's own decisions are
provisional: locks expire, and manual placement is documented as the
inferior mode. Omakase takes the opposite position: the plan is the user's,
and a block stays where the user put it. Today that holds at the API
(`timeblocks/` are only created and moved by the client); the calendar to
place them is planned M4.

What is worth taking is the arithmetic, not the placement: ETAs, "scheduled
past deadline", day capacity against placed estimates, and explicit triage
verbs, all as warnings on a plan the user owns. Motion has no study model,
no focus timer, no closing review, no native offline Mac client and no
student price. Omakase's API stores the data behind the first three
(semesters and disciplines, `pomodoro/sessions/`, `stats/reviews/`); its
Mac client shows none of them yet (planned M3-M5). The Mac client is
native and offline-capable, but only for its Today checklist.

## Reclaim.ai

The second auto-scheduler, kept brief.

- **1.0 to 2.0.** Reclaim 1.0 auto-schedules Tasks, Habits, Focus Time and
  Smart Meetings onto Google or Outlook. 2.0 is "a complete redesign of the
  AI calendar that introduces an Assistant", with an AI chat, a Planner
  with Preview Mode ("a calendar sandbox that lets you safely test changes
  ... and apply updates only when you're ready"), background agents, and
  MCP access. 1.0 users request early access to 2.0
  ([2.0 overview](https://help.reclaim.ai/en/articles/14846468-reclaim-ai-2-0-overview.md),
  [2.0 FAQ](https://help.reclaim.ai/en/articles/15280604-reclaim-2-0-faq.md)).
- **2.0 stops auto-scheduling individual tasks.** "Rather than creating
  calendar blocks for each task, Reclaim will recommend 3–5 tasks that are
  'Relevant Now' or flags tasks that are 'At Risk.'" and "If you are looking
  for auto-scheduling and rescheduling of individual Tasks, we recommend
  that you use Reclaim 1.0." Assistant changes are "first staged in Preview
  Mode"
  ([2.0 tasks](https://help.reclaim.ai/en/articles/16558552-reclaim-2-0-tasks-overview.md)).
  That is close to the morning plan promised in docs/IDEA.md §6: up to 5
  suggested blocks to accept, modify or dismiss.
- **How 1.0 schedules.** Priorities P1 Critical to P4 Low; higher can
  overbook lower; on a tie, Smart Meetings, then Habits, then Tasks, and
  Tasks by due date
  ([how Reclaim manages your schedule](https://help.reclaim.ai/en/articles/6207587-how-reclaim-manages-your-schedule-automatically.md)).
  Events sit as Free and turn Busy as the deadline or the day's load
  approaches
  ([time defense](https://help.reclaim.ai/en/articles/4129290-time-defense-settings-for-habits.md)).
- **Control (1.0).** "Events will also automatically lock anytime they are
  manually rescheduled by you", and a locked event "will no longer
  automatically reschedule ... even if it gets overbooked"
  ([locks](https://help.reclaim.ai/en/articles/6473767-how-to-stop-reclaim-events-from-moving-using-locks.md)).
  Smart Meetings auto-lock at 4am on the day; auto-lock ahead is optional
  for the rest
  ([auto-lock](https://help.reclaim.ai/en/articles/6750250-auto-lock-your-focus-time-habits-tasks-and-smart-meetings.md)).
  Unlike Motion, the lock does not expire. Deleting a task event means
  "please reschedule", so deleting a past event revives the task
  ([modify task events](https://help.reclaim.ai/en/articles/4292944-what-happens-when-you-modify-task-events-on-the-calendar.md));
  the help centre has a page titled "Tasks keep popping back up after being
  deleted"
  ([zombie tasks](https://help.reclaim.ai/en/articles/5899967-tasks-keep-popping-back-up-after-being-deleted.md)).
- **Habits**: flexible recurring routines with a window, duration range,
  frequency and priority ("between 11:30am and 2pm Mon-Fri"), 100+
  templates
  ([habits](https://help.reclaim.ai/en/articles/4129152-habits-overview-auto-schedule-flexible-time-for-your-routines.md)).
- **Focus Time** has a weekly goal, Proactive (fill ahead) or Reactive
  (block "only ... when you are at risk of missing that minimum"), and can
  decline meetings
  ([focus time](https://help.reclaim.ai/en/articles/6332766-focus-time-overview-defend-time-for-productive-work.md)).
- **Timer**: a free, separate web Pomodoro Timer (25/5/15, configurable)
  with its own analytics
  ([pomodoro](https://help.reclaim.ai/en/articles/12611123-how-to-use-the-reclaim-pomodoro-timer.md));
  2.0 tasks have a play/stop timer that logs time to the calendar (2.0
  tasks page).
- **Analytics**: up to 12 weeks of meetings, breaks, deep work (sessions
  over 2h) and shallow work
  ([stats](https://help.reclaim.ai/en/articles/4133660-stats-overview-reviewing-your-productivity-insights.md)).
- **Platforms**: "Reclaim doesn't have native apps for iOS or Android"; it
  is a web app or PWA
  ([mobile](https://help.reclaim.ai/en/articles/6916961-how-to-use-reclaim-on-your-mobile-device.md)).
  "Native mobile app for iOS" is on the public roadmap
  ([board](https://updates.reclaim.ai/board)).
- **Pricing**, per seat per month: Lite free (1-week range, 1 Habit, 2
  calendars), Starter $10 annual / $12 monthly, Business $15 / $18,
  Enterprise $22 annual only ([pricing](https://reclaim.ai/pricing);
  [plans](https://help.reclaim.ai/en/articles/6405975-how-reclaim-s-pricing-and-plans-work.md)).
  A 14-day trial drops to Lite: "You will never be charged unless you
  upgrade"
  ([end of trial](https://help.reclaim.ai/en/articles/6405151-what-happens-at-the-end-of-a-free-trial.md)).
- **Student plan**: "a 50% discount off of any Reclaim plan for up to 12
  months to educators, students, and school administrators", with a school
  email
  ([education](https://help.reclaim.ai/en/articles/6211178-education-discount-at-reclaim-ai.md));
  also 20% off for 6 months for users switching from "Calendly, Clockwise,
  or Motion"
  ([switching](https://help.reclaim.ai/en/articles/7838130-discounts-for-switching-providers-at-reclaim-ai.md)).

## 14. Sources

Motion:

- https://www.usemotion.com/
- https://www.usemotion.com/pricing
- https://www.usemotion.com/download
- https://www.usemotion.com/blog/motion-raises-60m-to-build-the-agentic-work-suite-for-businesses
- https://www.usemotion.com/help/llms.txt
- https://www.usemotion.com/help/readme.md
- https://www.usemotion.com/help/getting-started/what-is-motion.md
- https://www.usemotion.com/help/knowledge-management/data-hierarchy/reference-data-hierarchy/definitions.md
- https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md
- https://www.usemotion.com/help/project-management/task/task-scheduling-faq.md
- https://www.usemotion.com/help/project-management/meeting-events/reference-meeting-events/fixed-commitments.md
- https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/what-auto-scheduling-considers.md
- https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/manual-vs-auto-scheduling.md
- https://www.usemotion.com/help/time-management/auto-scheduling/auto-scheduling-how-to-guide.md
- https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/how-auto-scheduling-works-behind-the-scenes.md
- https://www.usemotion.com/help/time-management/auto-scheduling/concept-auto-scheduling/best-practices.md
- https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/scheduling-models-uni-and-bi-directional-sync.md
- https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/status-indicators.md
- https://www.usemotion.com/help/time-management/ai-agenda.md
- https://www.usemotion.com/help/time-management/ai-agenda/ai-agenda-how-to-guide.md
- https://www.usemotion.com/help/time-management/ai-agenda/concept-ai-agenda/purpose.md
- https://www.usemotion.com/help/project-management/dashboards/reference-dashboards.md
- https://www.usemotion.com/help/project-management/capacity-planning.md
- https://www.usemotion.com/help/getting-started/display-options/motion-desktop-tabs.md
- https://www.usemotion.com/help/getting-started/mobile-app/reference-mobile-app.md
- https://www.usemotion.com/help/getting-started/faq/account-and-login-faq.md
- https://www.usemotion.com/help/motion-support/cancel-your-plan.md
- https://www.usemotion.com/help/project-management/workspaces/reference-workspaces/billing-and-plans.md
- https://www.usemotion.com/help/time-management/all-things-calendars/reference-all-things-calendars/supported-providers.md
- https://www.usemotion.com/help/settings/integrations.md
- https://www.usemotion.com/help/settings/integrations/reference-integrations/native-integrations.md
- https://www.usemotion.com/help/settings/integrations/integrations-faq.md
- https://github.com/usemotion/desktopapp
- https://apps.apple.com/us/app/motion-tasks-ai-scheduling/id1580440623
- https://itunes.apple.com/us/rss/customerreviews/id=1580440623/sortBy=mostRecent/json

Reclaim.ai:

- https://help.reclaim.ai/llms.txt
- https://help.reclaim.ai/en/articles/14846468-reclaim-ai-2-0-overview.md
- https://help.reclaim.ai/en/articles/15280604-reclaim-2-0-faq.md
- https://help.reclaim.ai/en/articles/16558552-reclaim-2-0-tasks-overview.md
- https://help.reclaim.ai/en/articles/6207587-how-reclaim-manages-your-schedule-automatically.md
- https://help.reclaim.ai/en/articles/4129290-time-defense-settings-for-habits.md
- https://help.reclaim.ai/en/articles/6473767-how-to-stop-reclaim-events-from-moving-using-locks.md
- https://help.reclaim.ai/en/articles/6750250-auto-lock-your-focus-time-habits-tasks-and-smart-meetings.md
- https://help.reclaim.ai/en/articles/4292944-what-happens-when-you-modify-task-events-on-the-calendar.md
- https://help.reclaim.ai/en/articles/5899967-tasks-keep-popping-back-up-after-being-deleted.md
- https://help.reclaim.ai/en/articles/4129152-habits-overview-auto-schedule-flexible-time-for-your-routines.md
- https://help.reclaim.ai/en/articles/6332766-focus-time-overview-defend-time-for-productive-work.md
- https://help.reclaim.ai/en/articles/12611123-how-to-use-the-reclaim-pomodoro-timer.md
- https://help.reclaim.ai/en/articles/4133660-stats-overview-reviewing-your-productivity-insights.md
- https://help.reclaim.ai/en/articles/6916961-how-to-use-reclaim-on-your-mobile-device.md
- https://help.reclaim.ai/en/articles/6405975-how-reclaim-s-pricing-and-plans-work.md
- https://help.reclaim.ai/en/articles/6405151-what-happens-at-the-end-of-a-free-trial.md
- https://help.reclaim.ai/en/articles/6211178-education-discount-at-reclaim-ai.md
- https://help.reclaim.ai/en/articles/7838130-discounts-for-switching-providers-at-reclaim-ai.md
- https://reclaim.ai/pricing
- https://updates.reclaim.ai/board

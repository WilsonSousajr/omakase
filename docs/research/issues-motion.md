# Motion and Reclaim.ai - what their users keep asking for

> Captured **2026-09-25**, against `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered. This file mines **two** auto-schedulers together:
> Motion and Reclaim.ai.
>
> **Venues and sample.** Motion: the 150 most recent reviews in the US iOS
> App Store review feed
> ([feed](https://itunes.apple.com/us/rss/customerreviews/id=1580440623/sortBy=mostRecent/json),
> March 2025 to September 2026: 74 5-star, 14 4-star, 9 3-star, 8 2-star,
> 45 1-star), reviews on the
> [App Store listing](https://apps.apple.com/us/app/motion-tasks-ai-scheduling/id1580440623),
> and [Trustpilot](https://www.trustpilot.com/review/www.usemotion.com)
> (3.7/5, 578 reviews). Reclaim: its public roadmap
> ([board](https://updates.reclaim.ai/board)) and
> [Trustpilot](https://www.trustpilot.com/review/reclaim.ai) (2.2/5, 23
> reviews, a small sample). Trustpilot quotes come from a WebFetch summary
> of the page.
>
> **Coverage limits.** Reddit refused scripted access and search surfaced
> no threads, so there is no Reddit voice here. The Motion Mac App Store
> listing was not opened separately, and no G2 or Capterra reviews were
> read. Counts are keyword matches over the samples above. **The absence of
> a theme is not evidence of its absence.**
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

Everything from a review is **user voice**, never proof of how a feature
works. The mechanism behind each complaint is cited from the vendor's help
centre, as read for [`motion.md`](motion.md).

## The venue's character

**Motion has no public feedback board, roadmap or changelog.** Requests go
in-app: "click on the question mark icon ... 'Request a feature'"
([additional topics](https://www.usemotion.com/help/getting-started/faq/additional-topics.md)).
`motion.canny.io` answers "Company Not Found", and `/roadmap`, `/changelog`
and `/whats-new` return 404. The blog's product tag has undated posts
([product tag](https://www.usemotion.com/blog/tag/product)). Users
therefore talk in the App Store and on Trustpilot, where the reviews split
sharply: half 5-star, nearly a third 1-star.

**Reclaim has a public roadmap** on LaunchNotes with Backlog, In Planning,
In Development and Complete columns, and no vote counts
([board](https://updates.reclaim.ai/board)). Its Trustpilot sample is too
small to rank on its own, so Reclaim's quotes are used where they echo a
Motion theme.

## Pain points ranked by recurrence

### A. Billing and trial traps, no refund

Motion's most frequent 1-star theme: 24 of the 45 1-star reviews match
charge, refund, cancel, billing, subscription, scam or fraud, and it leads
Trustpilot's summary. "Have been charged $228 twice - unable to cancel or
refund" (2026-09-04, [feed]); "Will charge you without prior consent" (2026-04-30);
"Canceled but had already charged me $348 for the whole year" (2025-05-03);
"requires me to use desktop login to cancel the trial" (2025-06-20).

The design choice that causes it: refunds are not automatic, and
cancelling needs the desktop or web app
([cancel](https://www.usemotion.com/help/motion-support/cancel-your-plan.md)).
Reclaim does the opposite: a trial ends by dropping to the free tier, "You
will never be charged unless you upgrade"
([end of trial](https://help.reclaim.ai/en/articles/6405151-what-happens-at-the-end-of-a-free-trial.md)).

### B. Too expensive for one person

19 of the 62 Motion reviews rated 1 to 3 stars mention a price (overlapping
with A). "Wack and Overpriced ... $45 it costs a month" (2026-02-23, [feed]); "WAY
overpriced / $40 a month" (2025-06-16); "50$ for 1 seat" (2026-02-05); "it
was supposed to be 21/m then it was 69/m" (2025-12-08).

The design choice that causes it: an individual pays $49 a month for Pro
AI monthly and $69 for Business AI, with no student price
([pricing](https://www.usemotion.com/pricing)).

### C. It will not keep tasks where I put them

"Doesn't keep any tasks where I move them and moved everything around
constantly" (Motion, 2026-02-23, [feed]); "it scheduled me for Sunday at 7 am. Had
to do all the scheduling myself" (Motion, 2025-04-15); "schedules whatever
it wants" (Motion, [Trustpilot][tp-motion]). Reclaim: "I put the time of my meeting
because I need it to happen at an exact time — and it automatically
reschedules it"; "Added hundreds of focus time and lunches to my gcal (with
no warning)" ([Trustpilot][tp-reclaim]).

The design choice that causes it: a Motion lock lasts only until 60
minutes past its slot
([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)),
the plan reflows on every change
([behind the scenes](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/how-auto-scheduling-works-behind-the-scenes.md)),
and a deleted Reclaim task event can revive the task
([zombie tasks](https://help.reclaim.ai/en/articles/5899967-tasks-keep-popping-back-up-after-being-deleted.md)).

### D. The "AI" is distrusted

"let's not get ahead of ourselves and say there is artificial intelligence
in play here" (App Store listing review); "the AI keeps getting dates
wrong" (2026-07-06, [feed]); "the 'AI' scheduling is just an auto scheduler"
(2025-04-15); "AI hallucinates a lot and give you too many action items"
(Trustpilot).

The design choice that causes it (an inference, not documented): a
product sold as AI that decides for the user, so every wrong decision is
the AI's. The docs do say Motion "plans your day for you"
([readme](https://www.usemotion.com/help/readme.md)).

### E. Weak mobile and iPad apps, no notifications, no dark mode

"No mobile notifications ... this app cannot notify me to move on to the
next task" (2025-11-27, [feed]); "Using on iPad is half broken ... there is no iPad
app" (2025-07-21); "No Dark Mode" (2025-05-16, 2025-09-17); "Not for people
who schedule primarily via mobile ... doesn't support recurring task
creation" (2025-07-16). Reclaim: "I desperately need a phone app version"
(Trustpilot).

The design choice that causes it: Motion's mobile app is by its own docs
"quite a bit behind" desktop
([mobile app](https://www.usemotion.com/help/getting-started/mobile-app/reference-mobile-app.md)),
and "Reclaim doesn't have native apps for iOS or Android"
([mobile](https://help.reclaim.ai/en/articles/6916961-how-to-use-reclaim-on-your-mobile-device.md)).

### F. Too complex, slow to add a simple task

"Too complex for most uses ... Adding simple tasks takes too long"
(2025-03-25, [feed]); "too many videos to learn how to use it, each is 20 minutes
long" (2025-07-13); "huge learning curve" (Motion, [Trustpilot][tp-motion]); "Not user
friendly" (Reclaim, [Trustpilot][tp-reclaim]).

### G. Support is AI-only or silent

"There is no customer service ... It is all AI customer service"
(2026-05-01, [feed]); "Zero support ... no Live support" (2025-07-15); "NO response
from their support" (Trustpilot).

### H. Features removed after lock-in

"they removed the real AI Agenda and replaced with a static to do list"
(2025-07-15, [feed]); "you have taken away features from me" after "forcing me ...
into subscribing a year at a time and raising the price" (2026-01-09);
"pricing and models changed multiple times during my 30 day trial"
(2025-08-26). Reclaim's own docs send users who want per-task
auto-scheduling back to 1.0
([2.0 tasks](https://help.reclaim.ai/en/articles/16558552-reclaim-2-0-tasks-overview.md)).

The design choice that causes it (an inference): when the product's
value is its scheduling engine, redesigning the engine takes away the
product.

### I. Built for teams, not individuals

"Not useful for individuals ... Tailored to team projects" (2025-08-11, [feed]).
The vendor's own funding post names "small and mid-sized businesses"
([funding post](https://www.usemotion.com/blog/motion-raises-60m-to-build-the-agentic-work-suite-for-businesses)).

### J. Reliability: white screens, loading loops, lost data

"It doesn't load half the time, just pulls up a white screen for hours"
(2026-01-26, [feed]); "stuck on the loading screen" (2025-03-17); "calendar deleted
after 2+ years" (2025-11-22). The docs themselves warn that "Refreshing
your desktop app ... can cause data loss"
([desktop tabs](https://www.usemotion.com/help/getting-started/display-options/motion-desktop-tabs.md)).

### K. Requests: AI chat that creates events, a month view, recurring tasks

"I wish the AI chat can create events as well" (2026-07-06, [feed]); "no month
view" (App Store listing review). Reclaim's roadmap has "Recurring Tasks",
"Task dependencies" and "Projects" in Backlog
([board](https://updates.reclaim.ai/board)).

### L. The counterweight: nothing gets lost

"rearranging and never losing sight of a task is extremely helpful"
(2026-09-23, 4 stars, [feed]); "automatically reschedules tasks when plans change
throughout the day" (App Store listing review). What users value is that a
blown-up day loses nothing.

## Classification

Class: **(a)** Omakase's design already answers it; **(b)** structural to
their architecture, impossible in Omakase's; **(c)** Omakase also lacks it.

| Need | Evidence | Class | Omakase today |
|---|---|---|---|
| Easy cancel, no silent charge after a trial | A | (c) | Absent: no billing exists. |
| A price one person can pay | B | (c) | Absent: no price is set. |
| Blocks stay where the user put them | C | (a) | Shipped (API): a `TimeBlock` is a user-placed row (`backend/tasks/models.py`) and the server has no scheduler that moves it; only the client writes `timeblocks/`. No client can place one yet: the calendar is planned M4. Hand placement is a product choice, not something the architecture forbids changing, so not (b). |
| No autonomy claims to disappoint | D | (a) in design | Nothing is auto-placed today. Suggested blocks the user accepts, modifies or dismisses are promised only (docs/IDEA.md §6). A product choice, not architecture, so not (b). |
| Notifications to move to the next block | E | (c) | Planned M3 (notifications, menu-bar timer). |
| A real mobile and iPad client | E | (c) | Planned later (iOS, then Android; docs/ROADMAP.md). |
| Fast capture of a simple task | F | (c) | Planned M3 (global capture hotkey). A quick-capture inbox is promised only (docs/IDEA.md §17). |
| A human support channel | G | (c) | Absent; outside product design. |
| Features not removed from under the user | H | (a) partly | Shipped as a rule: AGENTS.md invariant 8 makes the API a contract with native clients, so a contract change is named in `CHANGELOG.md`; it does not stop a feature being removed. |
| Built for one person | I | (a) | Shipped: single-user by design; every read is scoped to the user (AGENTS.md invariant 1). |
| Usable when the server is slow or gone | J | (a) partly | Shipped for the Mac Today checklist only: SwiftData cache and an ordered outbox that replays with idempotency keys (M1). |
| Recurring tasks | K | (c) | Absent. Promised only (docs/IDEA.md §2; routines §14). Class occurrences are the only recurrence built, computed per request. |
| Month view | K | (c) | Absent; the planned calendar is day and week (M4). |
| Nothing lost when the day blows up | L | (a) partly | Shipped (API): `tasks/carried-over/?date=` lists incomplete tasks scheduled before the client's date. Rollover decisions in the daily review are planned M3 (docs/IDEA.md §8). |

## What the maintainers have not solved

- **Motion: billing trust.** Charge and refund complaints run from 2025
  into September 2026, and the docs still say refunds are not automatic.
- **Motion: mobile.** No iOS update since 2025-11-27 and no iPad build, per
  the [App Store listing](https://apps.apple.com/us/app/motion-tasks-ai-scheduling/id1580440623).
- **Motion: control.** The docs still call manual scheduling "Error-prone"
  ([manual vs auto](https://www.usemotion.com/help/time-management/auto-scheduling/reference-auto-scheduling/manual-vs-auto-scheduling.md))
  and let locks expire
  ([task states](https://www.usemotion.com/help/project-management/task/reference-tasks/task-states-and-task-types.md)).
- **Reclaim: per-task auto-scheduling in 2.0.** Its answer was to stop
  doing it and "recommend 3–5 tasks" with a Preview Mode, and to send users
  who want the old behaviour back to 1.0
  ([2.0 tasks](https://help.reclaim.ai/en/articles/16558552-reclaim-2-0-tasks-overview.md)).
- **Reclaim: native mobile.** "Native mobile app for iOS" sits on the
  roadmap ([board](https://updates.reclaim.ai/board)).

## Do-not-repeat lessons

1. Do not move a block the user placed. Motion users read it as loss of
   control (C).
2. Never let an explicit user choice expire quietly, the way a Motion lock
   does after 60 minutes.
3. Do not document manual control as the error case. The user is the
   planner.
4. Do not let overdue work poison the rest of the plan. Motion's own docs
   say untriaged overdue tasks "block your schedule" until cleared
   ([AI Agenda how-to](https://www.usemotion.com/help/time-management/ai-agenda/ai-agenda-how-to-guide.md)).
5. Do not make cancelling hard or charge silently after a trial (A).
   Reclaim's trial drops to the free tier instead.
6. Do not ship a mobile app that falls "quite a bit behind" desktop and
   then stop updating it.
7. Do not rebuild the core engine in a way that removes what users paid
   for. Reclaim's retreat from per-task auto-scheduling is primary-source
   evidence that even its vendor found automatic placement hard to make
   trustworthy.

[feed]: https://itunes.apple.com/us/rss/customerreviews/id=1580440623/sortBy=mostRecent/json
[tp-motion]: https://www.trustpilot.com/review/www.usemotion.com
[tp-reclaim]: https://www.trustpilot.com/review/reclaim.ai

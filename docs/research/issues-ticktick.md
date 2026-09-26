# TickTick - what its users keep asking for

> Captured **2026-09-25**, against Omakase's `develop` at `51abb80`. Every
> load-bearing claim below was checked against a live primary page on that
> date, not remembered.
>
> **Venues and sample.** TickTick has no official public feature-request
> forum, so two proxies were read. (1) An unofficial board,
> https://ticktick.featurevote.app/, read in full: 27 items. (2) The US App
> Store reviews of the iPhone app, from Apple's public feed
> `https://itunes.apple.com/us/rss/customerreviews/page=N/id=626144601/sortby=mosthelpful/json`,
> pages 1-10: the **500 "most helpful" reviews**, dated 2018-2026 (402
> five-star, 56 four-star, 23 three-star, 11 two-star, 8 one-star). All 42
> reviews rated 3 stars or lower were read in full, themes were
> keyword-counted across all 500 (counts are *mentions*, not complaints),
> and the student-related reviews were read. A review is cited as
> "ASR p.N #id", where N is the feed page and links to it.
>
> Every App Store review is **user voice**: it says what a user saw, never
> how a feature works. Mechanisms are cited from the help centre.
>
> **Coverage limits.** Reddit r/ticktick is not sampled: reddit.com and
> api.reddit.com returned HTTP 403 to scripted requests, and web search
> returned no r/ticktick threads. In-app feedback is not public. A "most
> helpful" sort favours older, longer reviews. **The absence of a theme
> here is not evidence that users do not want it.**
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## The venue's character

- **No official forum.** forum.ticktick.com does not resolve (curl: no
  connection), https://help.ticktick.com/forum returns 404, and
  https://support.ticktick.com/hc/en-us/community/topics redirects to the
  help-centre home. Feedback is taken in-app ("Help & Feedback",
  [help](https://help.ticktick.com/articles/7055781420970541056)), which is
  not public, so nothing on the vendor side is visibly answered.
- **The unofficial board is thin.** Its owner labels it "(UNOFFICIAL)
  Feature Board". All 27 items are "Requested"; none is Planned, In
  Progress or Completed. The top item has 13 votes. It is weak signal.
- **The App Store sample is mostly praise.** 458 of 500 reviews are four or
  five stars. The complaints below come from the 42 at three stars or
  lower, which makes each one count.

## Pain points ranked by recurrence

Ranked by the number of distinct low-star (≤3★) reviews among the 42 that
raise the point, then by board votes.

### A. Sync is unreliable or delayed across devices

Reviewers report that changes need a manual refresh, that reminders reach
other devices late, and that settings do not sync across apps.

- ASR [p.4] #5910637387 (2★, "the others will not sync until I open the
  app"); [p.3] #9064857324 (3★, "ZERO way to push changes … unless you click
  sync/refresh on both devices"); [p.5] #11888503077 (3★, "Settings don't
  sync across apps"); [p.1] #11825882405 (2★, Outlook calendar settings not
  saved).
- Board: "Fix cross-device reminder sync delays" (6 votes).
- 62 of 500 reviews mention sync.

**The design choice that causes it:** not documented. TickTick describes
cloud sync, and no help article mentions "offline" or states when changes
reach other devices ([`ticktick.md`](ticktick.md) §8).

### B. Paywall and subscription

Calendar views are paid on Mac and Windows, the free tier is capped, there
is no one-time purchase, and features have moved to paid.

- ASR [p.8] #12526589744 (2★, "on a Mac and Windows, the calendar view is a
  paid add on"); [p.6] #13033013666 (3★, "EVERYTHING is subscription"); [p.6]
  #11917575402 (3★, an update moved features to paid); [p.5] #10730211795
  (1★); [p.10] #13391504022 (2★); [p.6] #13477860753 (5★, a medical student
  who wants the free calendar view).
- 145 of 500 reviews mention price or premium.

**The design choice that causes it:** the planning surface itself -
calendar views and duration tasks - is on the Premium side
([upgrade](https://ticktick.com/upgrade)).

### C. Data loss and destructive defaults

"Import and Delete" from Reminders, a deleted section that took its tasks,
lost descriptions, lost appointments.

- ASR [p.4] #9688341540 (1★); [p.4] #6211509035 (3★); [p.10] #8512864512 (1★);
  [p.10] #9263268863 (1★); [p.6] #8585562781 (1★); [p.8] #13965365380 (2★).

**The design choice that causes it:** destructive operations offered as
defaults, with no recovery path users found.

### D. Recurring tasks break or are rigid

Repeats silently stop, a future occurrence cannot be checked off, and
repeated items nag as overdue.

- ASR [p.4] #12528936181 (2★, repeats "just stop repeating"); [p.9]
  #12493173998 (3★); [p.1] #11732543371 (3★).
- The help centre confirms "you cannot modify future recurring tasks until
  the current recurrence is completed"
  ([FAQ](https://help.ticktick.com/articles/7055792921664028672)).
- Board: "Show a repeat symbol", "Make selecting 'Won't Do' easier".

**The design choice that causes it:** the documented rule above - only
the current occurrence can be acted on. How recurrence is stored is not
documented.

### E. Features differ by platform

Features differ by device, and desktop lacks the timeline widget.

- ASR [p.5] #11888503077; [p.8] #12526589744.
- The docs confirm the Mac gaps: batch drag and Postpone are Windows and
  Web only, and the Mini Calendar is Web and Windows only
  ([calendar settings](https://help.ticktick.com/articles/7055782085826445312)).

**The design choice that causes it:** features ship per platform on
different schedules, as the help centre's own platform notes show. The
desktop tech stack is not documented ([`ticktick.md`](ticktick.md) §8).

### F. Reminders are rigid

The constant-reminder interval cannot be set, and a grouped notification
says only "3 tasks".

- ASR [p.1] #13468626991 (1★). Board: "Adjust frequency of Constant
  Reminders". 141 of 500 reviews mention reminders.

### G. The day boundary and "do date" versus due date

Focus sessions past midnight split across days, there is no do date, and
smart lists treat start and due dates inconsistently.

- Board: "add a do date" (13 votes, the top item); "Change day end time /
  new day start time for statistics" (7 votes, 2 comments).
- ASR [p.7] #3179238248 (4★, start versus due date in Today and Tomorrow).

**The design choice that causes it:** no do date separate from the start
and due dates (the top board ask), and a statistics day that ends at
midnight (the board's day-end ask).

### H. Too many clicks to reschedule

- ASR [p.3] #11608873978 (3★, "FIVE clicks" to move a task to today); [p.7]
  #11901844134 (4★, wants "a daily interface like Structured").
- Board: "Automatic Task Rollover configured per task" (7 votes).

**The design choice that causes it:** no guided daily plan is documented.
The closest is the Suggested Tasks panel, one "Add to Today" button per
task ([Suggested Tasks](https://help.ticktick.com/articles/7401564165023727616)).

### I. Performance and lag

- ASR [p.3] #11662264384 (2★, 5-10 s freezes, iOS habits); [p.4] #13607591778
  (3★, cannot reorder on mobile).

### J. The calendar is underpowered or wrong

Event times shown as the end time (an exam nearly missed), Google Calendar
events not editable (2019), a 3-day view wanted (2020, since shipped).

- ASR [p.7] #10629284350 (4★, "I almost went to my exam … at the time it
  ENDS"); [p.8] #5002619893 (3★, 2019); [p.5] #6018032215 (2020; the 3-Day
  View now exists,
  [Week View](https://help.ticktick.com/articles/7055782149730861056)).

### K. Small board asks (1-9 votes)

Estimated finish time for the day's tasks, habit notes, per-list "show
completed", advanced filters, tables in notes, custom shortcuts
(https://ticktick.featurevote.app/).

### What students say

88 of the 500 reviews mention school, class, study or similar. Praise is
for the all-in-one bundle: pomodoro, a calendar to timebox, lists per
class, and phone plus computer sync. "As a student, this app combines
features that were given by 5 different apps" (ASR [p.5] #8330049814). "I am
a full time student and full time office manager" (ASR [p.3] #14269599144,
5★, 2026-07-06). "my main calendar for school and work for the past 3
years" (ASR [p.6] #14491448705). These users are Omakase's target, and they
manage with general lists.

**No review in the 500 asks for a class timetable, a course entity or a
semester.** Students model classes as lists and tags. That says a
timetable is not a *demanded* gap among TickTick's English-speaking users.
It does not say a timetable adds no value: a feature users have not seen
is rarely requested. Dida365's portal and OCR import suggest the vendor
sees demand in China ([`ticktick.md`](ticktick.md) §6).

## Classification

Class: **(a)** Omakase's design already answers it, **(b)** structural to
TickTick's architecture and impossible in Omakase's, **(c)** Omakase also
lacks it.

| Need | Evidence | Class | Omakase today |
|---|---|---|---|
| Changes leave this device without a manual sync | A | (a) partly | shipped for the Today checklist only (Mac M1): the outbox replays queued writes in order and retries with backoff (`OmakaseStore/OutboxWorker.swift`); TickTick's own mechanism is not documented, so this is not (b) |
| Changes pushed to other devices | A | (c) | absent (one client, no push channel) |
| Timeboxing not behind a paywall | B | - (business model) | absent (no pricing yet); a user cannot timebox in any client today, `timeblocks/` is API only |
| A failed write kept, not lost | C | (a) partly | shipped for the Today checklist: a rejected write is parked with its error, a transient failure is retried (`OmakaseStore/OutboxWorker.swift`); the failed-writes sheet is planned M3. The reviewed losses come from destructive operations, whose cause is under undo and trash |
| Undo and trash | C | (c) | absent |
| Recurring tasks that do not silently stop | D | (c) | promised IDEA §2; only the class schedule recurs (API) |
| One feature set across platforms | E | (c) | absent as a guarantee: one Mac client today; iOS and Android are later, separate native clients that can drift the same way |
| Configurable reminders | F | (c) | notifications planned M3; no per-task reminders in the model |
| A do date apart from the due date | G | (a) | shipped (API): `scheduled_date` and `due_date` on tasks and study blocks |
| A configurable day boundary for night work | G | (c) | absent; "today" is the client's calendar date (invariant 2) |
| Fewer clicks to reschedule into today | H | (a) partly | `tasks/carried-over/?date=` shipped (API); complete/reschedule planned M3; morning plan promised IDEA §6 |
| Per-task automatic rollover | H | (c) | absent |
| Event times drawn correctly, classes visible | J | (a) partly | class occurrences computed (API); drawing them behind blocks planned M4 |
| Editing external calendar events | J | (c) | absent; a read-only Calendar.app overlay is planned M5 |
| Projected finish time for the day | K | (a) partly | `estimated_minutes` on Task and StudyBlock shipped (API, `backend/tasks/models.py:114`, `backend/study/models.py:118`); no client shows a projection |
| A class timetable | students | - (not requested in sample) | shipped (API): `study/classschedules/`, `study/class-occurrences/`; no client screen |

## What the maintainers have not solved

- **Offline.** No help article documents it, and low-star reviews still
  describe refresh-to-sync (A).
- **Recurrence editing.** The help centre states the "current must be
  completed first" rule as the design (D).
- **Mac parity.** The help centre itself lists features the Mac does not
  have (E).
- **A public place to ask.** There is no official board; the only public
  one is unofficial and unanswered.

## Do-not-repeat lessons

1. **Do not make the task its own time block.** A duration field on the
   task cannot express one task worked across several sessions
   ([`ticktick.md`](ticktick.md) §2, §12).
2. **Do not ship destructive defaults** such as "Import and Delete" (C).
3. **Do not model recurrence so that future occurrences are unreachable**
   (D).
4. **Do not let platforms drift**; each gap is visible in the docs and in
   reviews (E).
5. **Do not leave the offline contract undocumented**; users infer it from
   failures (A).
6. **Do not end the day at a hard midnight without saying so**; focus past
   midnight splits across days (G).

[p.1]: https://itunes.apple.com/us/rss/customerreviews/page=1/id=626144601/sortby=mosthelpful/json
[p.2]: https://itunes.apple.com/us/rss/customerreviews/page=2/id=626144601/sortby=mosthelpful/json
[p.3]: https://itunes.apple.com/us/rss/customerreviews/page=3/id=626144601/sortby=mosthelpful/json
[p.4]: https://itunes.apple.com/us/rss/customerreviews/page=4/id=626144601/sortby=mosthelpful/json
[p.5]: https://itunes.apple.com/us/rss/customerreviews/page=5/id=626144601/sortby=mosthelpful/json
[p.6]: https://itunes.apple.com/us/rss/customerreviews/page=6/id=626144601/sortby=mosthelpful/json
[p.7]: https://itunes.apple.com/us/rss/customerreviews/page=7/id=626144601/sortby=mosthelpful/json
[p.8]: https://itunes.apple.com/us/rss/customerreviews/page=8/id=626144601/sortby=mosthelpful/json
[p.9]: https://itunes.apple.com/us/rss/customerreviews/page=9/id=626144601/sortby=mosthelpful/json
[p.10]: https://itunes.apple.com/us/rss/customerreviews/page=10/id=626144601/sortby=mosthelpful/json

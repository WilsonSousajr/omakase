# Super Productivity - what its users keep asking for

> Captured **2026-09-25**. Every load-bearing claim below was checked against
> a live primary page on that date, not remembered.
>
> Venue: the GitHub issue tracker of
> [`super-productivity/super-productivity`](https://github.com/super-productivity/super-productivity)
> (the old `johannesjo/super-productivity` URL redirects there). Code
> references are to commit `a76c1bccea42f091ed42b1c48d7e78686247caa4`, read
> in [`super-productivity.md`](super-productivity.md).
>
> Sampling, all with `gh`:
>
> 1. **Recency sample.** `gh issue list --state all --limit 300`, sorted by
>    comment count. It returned [#9532] to [#10245], created 2026-08-10 to
>    2026-09-25: a 7-week window, not all time. Titles were bucketed by
>    keyword with `grep -ciE`; a title can land in several buckets.
> 2. **Topic sample.** `gh search issues --sort comments --limit 12` for
>    each of study, school, calendar, sync, pomodoro, review, timeblock,
>    recurring, mobile and offline. These are full-text searches, so they
>    return generally hot issues, not only on-topic ones.
> 3. **All-time top 30 by comments.** `gh search issues --sort comments
>    --limit 30`.
> 4. **Study title searches** for student, study, school, semester and exam.
>
> Sample size: 300 issues in (1), up to 120 in (2), 30 in (3), with
> overlaps. Five issue numbers, titles and comment counts ([#10119],
> [#4544], [#5737], [#2657], [#9627]) were re-checked live with
> `gh issue view` on the capture date. Omakase facts are from `develop`
> at `51abb80`.
>
> Comment count is the proxy for demand; reaction counts were not read.
> **Absence of a theme is not evidence of absence**: a user may not ask a
> work-framed app for something it was never meant to do.
>
> **Analysis only.** No implementation decision is made here;
> `docs/ROADMAP.md` decides (#105).

## The venue's character

The repository has 22,254 stars and 2,072 forks, and an
`open_issues_count` of 1,407, a figure that includes pull requests (GitHub
API, 2026-09-25). It was created 2017-01-06, is MIT-licensed, was last
pushed 2026-09-25T19:36:42Z, and its latest release is v19.1.0 of
2026-09-19.

Issue velocity is high: 300 issues cover only seven weeks, and sync and
mobile titles dominate them. How maintainers answer was not measured.

Keyword counts in the 300-issue recency sample:

| Bucket | Hits |
|---|---|
| sync / webdav / dropbox / nextcloud / supersync | 60 |
| android / ios / mobile / phone | 49 |
| schedule / planner / calendar / caldav / ical | 41 |
| focus / pomodoro / break | 12 |
| recurring / repeat | 11 |
| crash / won't start | 8 |
| worklog / summary / end of day / archive | 8 |
| timezone / utc / midnight | 5 |

The five study title searches returned 0 issues.

## Pain points ranked by recurrence

### A. Sync failures, divergence and resurrected data

The largest cluster in every sample.

- Recency: [#9627] (11 comments), [#9537] (11), [#10119] (10: "~100+
  already-completed/deleted tasks resurfacing"), [#9863] (8), [#10102] (6),
  [#9601], [#9768], [#10147] and [#10146] (tracked time diverges between
  clients), [#10116], [#9877], [#9633].
- All time: [#3288] (49), [#4437] (43), [#645] (43), [#4829] (40), [#4616]
  (39), [#599] (35), [#4391] (34), [#4544] (30, "Lost data because of
  synchronisation"), [#7330], [#7372], [#6397]. Also [#4857], "Implement
  CRDT for Conflict-Free Multi-Device Sync".

**The design choice that causes it.** Local-first with no authoritative
server, over file stores whose atomicity depends on their ETag support
(`docs/wiki/3.08-Sync-Integration-Comparison.md`). Vector clocks and
last-write-wins cover single-entity edits, but multi-entity operations stop
sync with `SYNC_MULTI_ENTITY_UNSUPPORTED`
(`src/app/op-log/core/errors/sync-errors.ts`; archive and time-rounding
cases in `src/app/op-log/testing/integration/`). Per-day time is an
absolute value on the task (`timeSpentOnDay`), so two clients that both
add time write two different totals.

### B. Mobile and WebView quality

[#9779] iOS performance (13 comments); [#9785], [#9793] and [#9799]
Android startup crashes; [#9675], [#9641], [#9956], [#9989], [#10132],
[#9850] and [#9893], a series on the phone UI; [#9857], [#10071]. 49 of the
300 recency titles mention mobile.

**The design choice that causes it.** One Angular app inside Capacitor
WebViews, storing data in IndexedDB that "can be lost if WebView storage is
evicted" (`docs/sync-and-op-log/sqlite-migration.md`).

### C. A schedule the user cannot read or control

[#9925] "schedule (make it understandable)", [#9991], [#9906] (the view
scrolls back every 5 minutes), [#9548] and [#10111] (work-day start and end
cannot be edited or turned off), [#9873], [#10063], [#9584]. Older:
[#5643] (scheduled time against due date), [#7033] and [#2737] (iCal
entries shown twice).

**The design choice that causes it.** The timeline is computed by flowing
estimated tasks around blocked time inside a configured work window
(`src/app/features/schedule/map-schedule-data/create-schedule-days.ts`).
The user never places a block, so the result surprises them.

### D. Recurring tasks: duplicates, misses, subtask copies

[#427] (50 comments), [#3227] (15), [#5594] (22), [#9728] (subtasks
duplicated), [#1902] (repeats ignore days the app was not opened), [#10202]
(overdue repeats pile up despite the option), [#10091] (repeat until a
date), [#10077], [#10074], and [#6230], recorded as a known gap in
`src/app/features/tasks/store/task-due.effects.ts`.

**The design choice that causes it.** Each client creates instances when
it sees a date change, after sync (`task-due.effects.ts`). Whether a day
gets its repeats, once, depends on which device opens first and when.

### E. Timezone and day-boundary bugs

[#9650] (the schedule tracks UTC instead of local time), [#9958] and
[#10237] (CalDAV items a day early; the query window is at UTC midnight),
[#10005] (date-only deadlines sort a day early at negative offsets),
[#9758] (a custom start of the next day), [#9950] (worklog weeks cut at
month boundaries), [#915].

**The design choice that causes it.** Epoch-millisecond fields
(`dueWithTime`) mixed with date strings (`dueDay`), plus a configurable
"start of next day" offset (`src/app/core/date/date.service.ts`).

### F. Focus and Pomodoro: a regression and missing controls

[#5737] (49 comments: the simple Pomodoro-with-tracking was removed),
[#9645] (per-task session length), [#9754] (a global pause hotkey), [#9924]
(start a break at any time), [#9979] (focus mode should prefer today's
tasks), [#9893].

**The design choice that causes it.** Pomodoro was folded into a focus
overlay with its own timer, decoupled from tracking the current task, and
the session is local UI state (`focus-mode-storage.service.ts`), not a
record.

### G. Finish day and archive stalls

[#9537], [#9768] and [#10102] (the bulk `moveToArchive` breaks sync);
[#216] (30 comments: the day cannot be finished, notifications loop);
[#10220] and [#10196] (a restore from the archive is undone by a
concurrent edit).

**The design choice that causes it.** "Finish day" is a bulk multi-entity
mutation, archiving every done task
(`src/app/pages/daily-summary/daily-summary.component.ts`), inside the
operation log.

### H. Hierarchy depth and project grouping

[#2657] (45 comments, open: subtasks of subtasks), [#516] (43, project
folders), [#163] (28, a daily list across projects), [#444].

**The design choice that causes it.** One level of `parentId`, and
projects as a flat list of work contexts
(`src/app/features/work-context/work-context.model.ts`).

### I. Integration churn

[#293] (55 comments, Trello), [#9909] (GitLab polling un-completes tasks),
[#10099], [#10096] and [#9830] (CalDAV two-way sync), [#3249] (Google
Calendar on Android), [#9939] (an OAuth token deleted on a transient
error), [#10070], [#10240].

**The design choice that causes it.** Many third-party pollers running on
the client, several now shipped as plugins (ADR #9 in
`ARCHITECTURE-DECISIONS.md`).

### J. Study

Zero titles about study, school, semester, exams or students, although
`funding.json` names students among the users (vendor-self-reported). This
is weak evidence either way.

## Classification

(a) Omakase's design already answers it. (b) Structural to Super
Productivity's architecture, impossible in Omakase's. (c) Omakase also
lacks it.

| Need | Evidence | Class | Omakase today |
|---|---|---|---|
| Sync that does not lose or resurrect data | A: [#10119], [#4544], [#3288] | (b) | shipped: the API server owns every row and serialises writes to PostgreSQL, so there is no file store, ETag race or client op log to diverge; Idempotency-Key on creates; the Mac outbox replays with idempotency keys (M1) |
| A policy for two offline edits to the same task | A, residual | (c) | absent |
| Tracked time that agrees across devices | A: [#10147], [#10146] | (b) | shipped: pomodoro/sessions/ are rows each client appends on the server, not a per-day total clients overwrite; the Mac timer is planned M3 |
| A phone app free of WebView storage eviction and WebView UI bugs | B: [#9779], [#9785] | (b) | SP's cause is one Angular app in Capacitor WebViews over IndexedDB; Omakase's clients are native (SwiftUI on the Mac, native iOS and Android "Later" in docs/ROADMAP.md). A phone app itself is absent, which is (c) |
| A schedule the user places and understands | C: [#9925], [#9991], [#5643] | (a) | shipped in the API: timeblocks/ (date, start, end, a task or a study block); the Mac calendar is planned M4 |
| Plan date separate from deadline | [#405], [#7069], [#5643] | (a) | shipped: tasks have scheduled_date and due_date |
| Repeats created once, on the right day | D: [#427], [#6230] | (c) | absent: recurring tasks are promised only (IDEA §2). The one recurrence built, class occurrences, is computed on the server per request and not stored (`study/class-occurrences/`), but nothing yet applies that shape to tasks, so this is not (b) |
| Repeat options: until a date, skip overdue, subtask templates | D: [#10091], [#10202], [#9728] | (c) | promised IDEA §2 |
| One "today" whatever the timezone | E: [#9650], [#10005] | (a) | shipped: the client sends ?date= (invariant 2) |
| A custom day rollover | E: [#9758] | (c) | absent |
| Correct timezones on calendar import | E: [#9958], [#10237] | (c) | absent: Google Calendar import is promised IDEA §5 |
| A simple Pomodoro tied to the work item | F: [#5737] | (a) | shipped in the API: pomodoro/sessions/ (focus, short and long break, duration, completed), with an optional task (not a study block; `backend/pomodoro/models.py`); the Mac timer is planned M3 |
| Per-task session length, a pause hotkey, a break on demand | F: [#9645], [#9754], [#9924] | (c) | absent |
| A finish-day that cannot stall sync | G: [#9537], [#10102], [#216] | (b) | shipped in the API: stats/reviews/, one review per day, an idempotent create that archives nothing; the Mac review is planned M3 |
| Subtasks of subtasks | H: [#2657] | (c) | absent: subtasks are one level |
| Grouping above projects; a list across projects | H: [#516], [#163] | (a) | shipped in the API: workspaces/ -> projects/ -> tasks/, and tasks/today/?date=; the Mac projects screens are planned M5 |
| Trello, GitLab, CalDAV, Google Calendar integrations | I: [#293], [#9830], [#3249] | (c) | absent: Google Calendar import IDEA §5 and sync IDEA §19 are promised; a read-only Calendar.app overlay is planned M5 |
| Semesters, disciplines, a class timetable | J: 0 issues | (a), demand unvalidated | shipped in the API: study/semesters/, disciplines/, studyblocks/, classschedules/, class-occurrences/ |

## What the maintainers have not solved

- **Subtasks of subtasks.** [#2657] is open with 45 comments.
- **Missed repeat creation.** [#6230] is recorded in the code as a known
  gap (`task-due.effects.ts`), with an end-to-end test named after it.
- **Silent loss.** The conflict journal is disabled in production, and its
  own document says it "is also not a no-silent-loss guarantee"
  (`docs/sync-and-op-log/conflict-journal-and-review.md`). A stopped sync is
  resolved by keeping one side, and "Either choice replaces the entire
  losing dataset" (`docs/wiki/3.06-User-Data.md`).
- **Durable mobile storage.** The SQLite move is designed but "not wired"
  (`docs/sync-and-op-log/sqlite-migration.md`, [#7892], [#7931]).
- **Hosted sync.** SuperSync is still labelled beta
  (`docs/wiki/3.08-Sync-Integration-Comparison.md`), and no price is
  published for it.

## Do-not-repeat lessons

1. **Do not create recurring instances on each client.** Whether a day
   gets its repeats then depends on which device opens first ([#6230]).
   Omakase's class occurrences are computed in one place, per request.
2. **Do not derive the timeline from estimates.** Users cannot read a
   schedule they did not place (C).
3. **Do not make the end of day a bulk mutation.** SP's archive-all step
   is what stalls sync (G); Omakase's review is one row.
4. **Do not store tracked time as a total that clients overwrite.** Two
   clients then write two totals ([#10146], [#10147]).
5. **Do not replace a working timer with a mode.** [#5737] is the most
   commented focus issue, and it asks for the old, simpler behaviour back.
6. **Do not let "today" depend on the machine's clock or a UTC boundary.**
   Invariant 2 already rules it out.
7. **Treat integrations as scope, not as features.** Every poller in
   section I is a maintenance line of its own.

## Could not verify

- SuperSync hosted pricing: the terms of service anticipate paid features,
  but no price is published.
- Reaction counts: comment counts were used instead.
- Anything older than seven weeks outside the top-30 and topic searches.

[#163]: https://github.com/super-productivity/super-productivity/issues/163
[#216]: https://github.com/super-productivity/super-productivity/issues/216
[#293]: https://github.com/super-productivity/super-productivity/issues/293
[#405]: https://github.com/super-productivity/super-productivity/issues/405
[#427]: https://github.com/super-productivity/super-productivity/issues/427
[#444]: https://github.com/super-productivity/super-productivity/issues/444
[#516]: https://github.com/super-productivity/super-productivity/issues/516
[#599]: https://github.com/super-productivity/super-productivity/issues/599
[#645]: https://github.com/super-productivity/super-productivity/issues/645
[#915]: https://github.com/super-productivity/super-productivity/issues/915
[#1902]: https://github.com/super-productivity/super-productivity/issues/1902
[#2657]: https://github.com/super-productivity/super-productivity/issues/2657
[#2737]: https://github.com/super-productivity/super-productivity/issues/2737
[#3227]: https://github.com/super-productivity/super-productivity/issues/3227
[#3249]: https://github.com/super-productivity/super-productivity/issues/3249
[#3288]: https://github.com/super-productivity/super-productivity/issues/3288
[#4391]: https://github.com/super-productivity/super-productivity/issues/4391
[#4437]: https://github.com/super-productivity/super-productivity/issues/4437
[#4544]: https://github.com/super-productivity/super-productivity/issues/4544
[#4616]: https://github.com/super-productivity/super-productivity/issues/4616
[#4829]: https://github.com/super-productivity/super-productivity/issues/4829
[#4857]: https://github.com/super-productivity/super-productivity/issues/4857
[#5594]: https://github.com/super-productivity/super-productivity/issues/5594
[#5643]: https://github.com/super-productivity/super-productivity/issues/5643
[#5737]: https://github.com/super-productivity/super-productivity/issues/5737
[#6230]: https://github.com/super-productivity/super-productivity/issues/6230
[#6397]: https://github.com/super-productivity/super-productivity/issues/6397
[#7033]: https://github.com/super-productivity/super-productivity/issues/7033
[#7069]: https://github.com/super-productivity/super-productivity/issues/7069
[#7330]: https://github.com/super-productivity/super-productivity/issues/7330
[#7372]: https://github.com/super-productivity/super-productivity/issues/7372
[#7892]: https://github.com/super-productivity/super-productivity/issues/7892
[#7931]: https://github.com/super-productivity/super-productivity/issues/7931
[#9532]: https://github.com/super-productivity/super-productivity/issues/9532
[#9537]: https://github.com/super-productivity/super-productivity/issues/9537
[#9548]: https://github.com/super-productivity/super-productivity/issues/9548
[#9584]: https://github.com/super-productivity/super-productivity/issues/9584
[#9601]: https://github.com/super-productivity/super-productivity/issues/9601
[#9627]: https://github.com/super-productivity/super-productivity/issues/9627
[#9633]: https://github.com/super-productivity/super-productivity/issues/9633
[#9641]: https://github.com/super-productivity/super-productivity/issues/9641
[#9645]: https://github.com/super-productivity/super-productivity/issues/9645
[#9650]: https://github.com/super-productivity/super-productivity/issues/9650
[#9675]: https://github.com/super-productivity/super-productivity/issues/9675
[#9728]: https://github.com/super-productivity/super-productivity/issues/9728
[#9754]: https://github.com/super-productivity/super-productivity/issues/9754
[#9758]: https://github.com/super-productivity/super-productivity/issues/9758
[#9768]: https://github.com/super-productivity/super-productivity/issues/9768
[#9779]: https://github.com/super-productivity/super-productivity/issues/9779
[#9785]: https://github.com/super-productivity/super-productivity/issues/9785
[#9793]: https://github.com/super-productivity/super-productivity/issues/9793
[#9799]: https://github.com/super-productivity/super-productivity/issues/9799
[#9830]: https://github.com/super-productivity/super-productivity/issues/9830
[#9850]: https://github.com/super-productivity/super-productivity/issues/9850
[#9857]: https://github.com/super-productivity/super-productivity/issues/9857
[#9863]: https://github.com/super-productivity/super-productivity/issues/9863
[#9873]: https://github.com/super-productivity/super-productivity/issues/9873
[#9877]: https://github.com/super-productivity/super-productivity/issues/9877
[#9893]: https://github.com/super-productivity/super-productivity/issues/9893
[#9906]: https://github.com/super-productivity/super-productivity/issues/9906
[#9909]: https://github.com/super-productivity/super-productivity/issues/9909
[#9924]: https://github.com/super-productivity/super-productivity/issues/9924
[#9925]: https://github.com/super-productivity/super-productivity/issues/9925
[#9939]: https://github.com/super-productivity/super-productivity/issues/9939
[#9950]: https://github.com/super-productivity/super-productivity/issues/9950
[#9956]: https://github.com/super-productivity/super-productivity/issues/9956
[#9958]: https://github.com/super-productivity/super-productivity/issues/9958
[#9979]: https://github.com/super-productivity/super-productivity/issues/9979
[#9989]: https://github.com/super-productivity/super-productivity/issues/9989
[#9991]: https://github.com/super-productivity/super-productivity/issues/9991
[#10005]: https://github.com/super-productivity/super-productivity/issues/10005
[#10063]: https://github.com/super-productivity/super-productivity/issues/10063
[#10070]: https://github.com/super-productivity/super-productivity/issues/10070
[#10071]: https://github.com/super-productivity/super-productivity/issues/10071
[#10074]: https://github.com/super-productivity/super-productivity/issues/10074
[#10077]: https://github.com/super-productivity/super-productivity/issues/10077
[#10091]: https://github.com/super-productivity/super-productivity/issues/10091
[#10096]: https://github.com/super-productivity/super-productivity/issues/10096
[#10099]: https://github.com/super-productivity/super-productivity/issues/10099
[#10102]: https://github.com/super-productivity/super-productivity/issues/10102
[#10111]: https://github.com/super-productivity/super-productivity/issues/10111
[#10116]: https://github.com/super-productivity/super-productivity/issues/10116
[#10119]: https://github.com/super-productivity/super-productivity/issues/10119
[#10132]: https://github.com/super-productivity/super-productivity/issues/10132
[#10146]: https://github.com/super-productivity/super-productivity/issues/10146
[#10147]: https://github.com/super-productivity/super-productivity/issues/10147
[#10196]: https://github.com/super-productivity/super-productivity/issues/10196
[#10202]: https://github.com/super-productivity/super-productivity/issues/10202
[#10220]: https://github.com/super-productivity/super-productivity/issues/10220
[#10237]: https://github.com/super-productivity/super-productivity/issues/10237
[#10240]: https://github.com/super-productivity/super-productivity/issues/10240
[#10245]: https://github.com/super-productivity/super-productivity/issues/10245

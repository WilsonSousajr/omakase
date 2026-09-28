# Competitive parity - an honest audit

> 2026-09-25, against `develop` at `51abb80`. The self-critical pass of
> #105, the sibling of `ai-memory`'s and omatty's `competitive-parity.md`.
> It takes the four differentiation hypotheses #105 started from and keeps
> only the ones that can name a file in this tree. A hypothesis that
> cannot is deleted here, in the open, rather than left to decorate a
> pitch.
>
> **Analysis only.** What Omakase does about any of it is decided in
> `docs/ROADMAP.md` (#105).

## The migration bar

A person switches planners when the new one does their daily loop at least
as well as the old one **and** gives them something the old one cannot.
The first half is the bar; the second is the reason. A reason without the
bar gets tried for a week and dropped.

For Omakase's user - a student who works, or a learner with a job - the
loop is: see today's classes, study blocks and work together; place them;
work them in a timer; close the day. Every competitor in camps A and C
clears the first half for the work side of that loop. **Omakase clears it
for neither side today**, because its client has two screens: sign-in and
a checklist (`apps/apple/Packages/OmakaseFeatures/Sources/OmakaseFeatures/`).
So every verdict below is conditional on a milestone, and the honest
verdict for today is the same for everyone: do not switch yet.

## The four hypotheses, tested

#105 began from four claims about what makes Omakase different. Each is
tested against the code and against the field.

1. **One timeline for work and study.** `backend/tasks/models.py`
   (`TimeBlock`): a block belongs to a task or a study block, enforced by
   the serializer and by the `timeblock_has_task_or_study_block`
   constraint; `backend/study/` holds the timetable. No product in the
   landscape's feature table has both halves (`2026-landscape.md` §2).
   **Kept - and it is the only real moat.** It is unshipped: no client
   draws a time block yet (M4).
2. **Plan → focus → review as one cycle.** The API has each part
   (`timeblocks/`, `pomodoro/sessions/`, `stats/reviews/`). But Sunsama,
   Akiflow and Ellie ship the whole ritual in a UI, and Super
   Productivity's finish-day records more than Omakase's review does.
   **Deleted as a moat.** The cycle is parity at best, and behind today.
   What is different is that the cycle includes the study half, which is
   hypothesis 1.
3. **Native macOS, offline-first, with an idempotent outbox.**
   `apps/apple/Packages/OmakaseStore/Sources/OmakaseStore/Outbox.swift`,
   `OutboxWorker.swift`, `backend/idempotency/services.py`. Real, and a
   different category from Sunsama (no offline), Motion and Reclaim
   (Electron and a PWA, offline not documented) and Super Productivity
   (last-write-wins). **Kept, narrowed:** it is parity with Things (a full
   local database) and Todoist (documented offline), and it covers one
   action today.
4. **Single-user, self-hosted data.** Omakase is single-user, but the
   server is the author's VPS, not something a user hosts. Super
   Productivity needs no account at all and Lunatask encrypts end to end
   (`2026-landscape.md` §2). **Deleted.** It is a deployment fact, not a
   property a user can choose Omakase for.

## Omakase's verified moat

Each line names the file. The qualifiers are part of the claim.

1. **Work and study share one set of time blocks.** `TimeBlock` in
   `backend/tasks/models.py`, lines 204-227. Nobody else in the field has
   this. **Not usable until M4.**
2. **Class occurrences are computed, not stored.** `ClassOccurrenceView`
   in `backend/study/views.py`. No duplicate instances to reconcile. **This
   is not a moat against student planners** - MyStudyLife and Power Planner
   model timetables better (rotations, holidays). It is a moat against the
   recurring-task bugs of work planners, if R2 reuses it.
3. **"Today" is the client's day, and the server refuses to guess.**
   `backend/omakase/client_dates.py:25`. **Not a moat; a precondition** -
   device-local apps get the day right by default. It matters because
   Omakase has a server that would otherwise get it wrong.
4. **A write is never lost and never doubled.** The outbox and
   `IdempotentCreateMixin` (`backend/idempotency/`). **Real against the
   Electron and web camp, parity against Things.** One action today.
5. **The API contract is tested.** `tools/tests/test_contract_fixtures.py`
   and invariant 8. MyStudyLife's v2 broke its own clients. **Real, and
   invisible to a user until the day it saves them.**

## Did Omakase copy without improving?

| Idea | Who else | Did Omakase improve on it? |
|---|---|---|
| Timeboxing tasks on a calendar | Twelve of fourteen planners, and Google Calendar for free | **No.** Parity, and not yet shipped in a client. |
| Pomodoro timer | Sunsama, TickTick, Structured, Ellie, Super Productivity, Session, Flow, Forest | **No.** A session records a task only (`backend/pomodoro/models.py`); a study block cannot be the subject of a timer session. |
| Daily review and shutdown | Sunsama, Akiflow, Ellie, Super Productivity | **No, behind.** A 1-5 rating and a win of the day; Super Productivity also records impact and energy. |
| Carried-over work | Sunsama (rolled-over marker), TickTick | **Parity** in the API (`tasks/carried-over/`). |
| Plan date apart from deadline | Super Productivity (`dueDay` / `deadlineDay`) | **Parity** (`scheduled_date`, `due_date`). |
| Work hierarchy | Everyone | **Parity.** |
| Class timetable | MyStudyLife, Power Planner, Shovel | **No, behind.** No rotation, holidays or cancellations. |
| Offline writes | Todoist, Things, Akiflow (desktop), Lunatask (short-term) | **Yes, against last-write-wins:** ordered, idempotent replay that parks rejects and their dependents. Parity with Things. |
| Timetable and work on one timeline | **Nobody** | **Not an improvement - an addition.** This is the whole moat, and it is not yet on a screen. |

The table's honest reading: outside row nine, Omakase is at parity or
behind on every idea it shares with the field. That is not a failure of
the design; it is what a backend without a client looks like.

## Migration verdicts

| From | Migrate to Omakase? | You gain | You give up |
|---|---|---|---|
| **TickTick** | **Not today.** After M4, only if you are a student. | Your timetable beside your tasks (TickTick has one only in its China edition); a plan-and-close ritual TickTick does not have | Habits, a mature focus timer with statistics, every platform, recurring tasks, reminders |
| **Sunsama** | **Not today.** After M4, only if you study. | Study on the same day as work; offline writes; a native app; a price that does not exist yet | A polished ritual with a workload threshold, weekly objectives, integrations, a phone app |
| **Super Productivity** | **Not today, and maybe not after.** | A server that cannot lose your data to a merge; study | Local-first privacy with no account, integrations, every platform, open source |
| **MyStudyLife / Power Planner** | **Not today.** After M4 if you also work, after R3 if your school rotates. | Your job and your classes on one day; time blocks instead of due dates only; a focus timer | Rotations, holidays, grades and GPA, reminders, a phone app |
| **Motion / Reclaim** | **Only if you want control back.** After M4. | Blocks that stay where you put them; no subscription | Automatic placement and rescheduling, team features, integrations |
| **Google Calendar with Tasks** | **Not today.** After M3 and M4, if the loop matters to you. | A timer, a daily review, study blocks and a timetable | It is free, it is already on your phone, and it syncs with everything |
| **Notion + Notion Calendar** | **Not today.** After M4, if you are tired of building your own templates. | A timetable, a timer and a review that exist without building them | Notes, databases, and a planner you shaped yourself |
| **Things / OmniFocus** | **Different job.** | Timeboxing, a timer, study | A mature, native, offline list manager |

## Honest gaps

- **The loop has no client.** P0-1 in `prior-art-findings.md`.
- **No recurring tasks.** Asked for in all five venues.
- **No phone.** Asked for in all five venues; "Later" in the roadmap.
- **No reminders.** Four venues.
- **No calendar sync or import.** A read-only Calendar.app overlay is
  planned for M5; Google Calendar sync is promised only.
- **The timetable is thinner than every student planner's.**
- **No distribution.** No App Store, no TestFlight, by the Mac spec. Even
  a finished Omakase cannot be installed by anyone but its author.

## Bottom line

- One hypothesis survives as a moat: **work and study on one set of time
  blocks.** It is real in the data model and nobody else has it. It is also
  on no screen.
- Two survive narrowed: the offline outbox (real against the Electron and
  web camp, parity with Things) and the API contract (real, invisible).
- Two are deleted: the plan-focus-review cycle as such (the ritual camp
  ships it), and self-hosting (not a user property).
- Every migration verdict reads "not today". The earliest any of them
  changes is M4, and for students the one that changes it most is R3.

# How Omakase compares

A fair, specific comparison with the planners a working student or a
learner with a job is likely to use today. Checked against each product's
own pages on 2026-09-25; the evidence, with a link for every claim, is in
`docs/research/`. If something here reads as unfair or out of date, open
an issue.

## The short version

Omakase puts **your classes, your study blocks and your work on one day**,
works them in one timer, and closes them in one review. No planner
checked for this comparison does that: work planners have no timetable,
and student planners do not plan work.

Omakase is early. Its API does all of the above; its Mac app, today, lets
you sign in and tick off today's tasks, offline. Until the daily loop
(M3) and the calendar (M4) ship, every product below is the better choice
for daily use.

## By camp

| Camp | Examples | Strength | Compared with Omakase |
|---|---|---|---|
| Daily-planning rituals | Sunsama, Akiflow, Ellie, Structured | A guided morning plan and evening shutdown, polished | No study side; Sunsama is Electron with no offline mode |
| AI auto-schedulers | Motion, Reclaim | The software places your blocks | Omakase lets you place them; Reclaim 2.0 itself moved to suggesting |
| Task managers with calendar | TickTick, Todoist, Things, OmniFocus, Super Productivity | Mature lists, every platform, recurring tasks | TickTick's timetable exists only in its China edition; the rest have none |
| Student planners | MyStudyLife, Power Planner, Shovel | Timetables with rotations, holidays, grades | They plan due dates, not your hours, and none plans a job |
| Focus timers | Forest, Session, Flow, Focusmate | A good timer | Timers, not planners |
| Calendars you already have | Google Calendar, Apple Calendar, Notion Calendar | Free, and task time blocks are now built in | No timetable, no timer, no daily review |

## Where Omakase is different

- **Work and study are one kind of block.** A time block belongs to a
  task or to a study block, and your class timetable is computed into the
  same days. Nothing else checked has both halves.
- **Offline writes that are never lost and never doubled.** Changes are
  queued in order on your Mac and replayed with idempotency keys, so a
  retry after a timeout cannot create a second copy. Today this covers
  completing a task.
- **You place the blocks.** A time block has the start and end you gave
  it; nothing rearranges your day behind your back.
- **Native on the Mac.** SwiftUI, not a web page in a window.

## Where others are ahead

| | Who | What Omakase lacks |
|---|---|---|
| The daily loop, usable today | Sunsama, Akiflow, Ellie, TickTick, Super Productivity | Everything past a Today checklist, until M3 and M4 |
| Recurring tasks | TickTick, Sunsama, Super Productivity, MyStudyLife+ | Planned in M8 |
| A phone app | Nearly every product checked (Reclaim and Focusmate are web-only) | iOS comes after the Mac; Android after that |
| Reminders | TickTick, MyStudyLife | Planned in M3 |
| A full timetable | MyStudyLife, Power Planner | Rotations, holidays and cancelled classes are planned in M8 |
| Grades | MyStudyLife, Power Planner | Not planned yet |
| Calendar sync and integrations | Sunsama, Akiflow, Super Productivity | A read-only Calendar.app overlay in M5; nothing else yet |
| Habits | TickTick, Lunatask | Not on the roadmap |
| Installing it | Everyone | Omakase has no public distribution yet |

## Coming from another tool?

- **From TickTick:** you would gain your timetable beside your tasks and a
  plan-and-close ritual; you would give up habits, a mature focus timer,
  every platform, and recurring tasks until M8.
- **From Sunsama:** you would gain study on the same day as work and a
  native app that works offline; you would give up a polished ritual,
  integrations and a phone app.
- **From MyStudyLife or Power Planner:** you would gain your job on the
  same day as your classes, and time blocks instead of due dates only;
  you would give up grades, rotations (until M8) and a phone app.
- **From Motion or Reclaim:** you would gain blocks that stay where you
  put them; you would give up automatic rescheduling.
- **From Google Calendar or Notion Calendar:** you would gain a timetable,
  a timer and a review without building them; you would give up "free
  and already on your phone".

## Honest summary

Omakase is betting on one thing nobody else does - work and study on one
day - and it has built that bet into its data model before building the
screens that show it. Until those screens ship, use one of the tools
above. When they do, the question for a working student is whether one
day for both is worth giving up a phone app and a year of polish.

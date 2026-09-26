# Omakase roadmap

Omakase is a DRF API for a planning and focus app spanning work and study.
Its web client was removed in #62. The next client is a native macOS app,
followed by native iOS and Android as a later epic.

Milestones are vertical slices. Each one produces something usable on its
own, and each is labelled `M<n>` on its issues. `docs/IDEA.md` holds the full
product vision and feature specification; this page holds the order and the
reasons for it.

## Where things stand

| | Milestone | Status |
|---|---|---|
| M0 | Groundwork | **Done.** #63-#66 and #69, merged to `develop` 2026-09-25 as PRs #67-#71 and #79. |
| M1 | Foundation | **Built, not yet smoke-tested.** Backend #76-#78 merged (PRs #80-#82). Apple #85-#91 as the stacked PRs #92-#98. The real-stack smoke run waits on the macOS OAuth client. |
| M2 | Identity | Next. |
| M7 | The Field | **In progress.** The research is #106-#118 (PRs #111-#120); this section and `docs/comparison.md` are #121. Runs alongside M2. |
| M3-M4 | The daily loop, Plan | Planned below, with what M7 added. |
| M8 | Repeats and exceptions | Planned, after M4. From M7. |
| M5-M6 | Parity, Production | Planned below. |

## M0 - Groundwork

**Delivers:** the conventions and the quality gate the macOS client's API
work will be held to, before that work starts.

**Contents:**

- #63 `AGENTS.md` as the one agent instruction file, from a prompt audit.
- #64 dependencies past eight known vulnerabilities.
- #65 `/tasks/today/` stops answering for the server's UTC day.
- #66 the quality gate: measured, pinned, and checked against itself.

**Why first:** a gate added after the API grows new endpoints for a new client
has to be set around whatever those endpoints turned out to be. Set now, it is
measured against a backend whose behaviour is known and covered.

**Done when:** all four are merged to `develop` with the gate green in CI.

The milestones below come from the macOS client's design,
`docs/superpowers/specs/2026-09-25-macos-client-design.md`. Each one ends
with the real app against the real local stack (`apps/apple/SMOKE.md`),
because the gate proves units, not the wiring between them.

## M1 - Foundation

**Delivers:** a Mac app you sign into with Google that shows today's tasks
from a local SwiftData cache, readable offline, and completes a task offline
through an outbox that replays in order when the API is reachable.

**Contents:**

- The backend changes the client needs: one strict `?date=` parser (#69),
  Google tokens from several OAuth clients (#76), `Idempotency-Key` on the
  creates the outbox replays (#77), and contract fixtures the Swift DTOs
  decode (#78).
- `apps/apple/`: three packages (`Features → Store → API`), the Apple gate
  (#85), DTOs (#86), the API client (#87), Google PKCE (#88), read sync
  (#89), the outbox (#90), and sign-in plus Today (#91).

**Why first:** everything later is a screen on top of this. Offline
behaviour, token refresh and idempotent replay are cheapest to get right
before there are screens depending on them.

**Done when:** #92-#98 are merged and `SMOKE.md` passes against the local
stack.

## M2 - Identity

**Delivers:** Omakase's visual identity on Liquid Glass, designed fresh:
palette, type scale, glass tinting, and the Today/Focus layout, as mockups
first and then as tokens applied to the shell (`docs/design-system-apple.md`).

**Why before M3:** M3 builds the screens you use every day. Building them on
a placeholder look means building them twice.

**Also decides (from M7, R7):** the macOS deployment target. macOS 27
shipped on 2026-09-14 and `apps/apple/project.yml` targets 26.0. Liquid
Glass is the reason either answer might be right, so the identity work is
where it gets decided, on purpose rather than by default.

## M7 - The Field

**Delivers:** a record of the field Omakase ships into, and the decisions it
forced, made here in the open. Numbered by when it was opened, not by when
it runs: it runs beside M2 because its findings re-scope M3 to M5.

**Contents:** the research in `docs/research/`, one issue and one PR each -
the landscape (#106, #110), five deep dives (#107), five venues mined for
what users keep asking for (#108), the field measured against this code
(#117), and the self-critical parity audit (#118). `docs/comparison.md`
and this section are #121; the method, for the next pass, is #122.

**What it found:**

- **The square is empty and unshipped.** No product checked has work tasks
  and a class timetable on one calendar; TickTick has a timetable only in
  its China edition. Omakase has both in its data model and on no screen.
- **Timeboxing is the floor.** Google Calendar blocks time for tasks, free,
  since November 2025. Omakase cannot be chosen for it.
- **What the field agrees on:** recurring tasks, a phone app at parity, and
  not losing data are asked for in all five venues. Omakase has the third
  for one action on one platform, and neither of the others.
- **Two of #105's four hypotheses did not survive.** The plan-focus-review
  cycle is shipped by the ritual camp; self-hosting is not a user property.

**Taken:** R2 and R3 are M8. R4, R5, R8 and R10 are in M3. R7 is in M2. The
DST test from R3 is in M5. R6 is how `docs/comparison.md` is written. R9 is
argued under "Later". R1 is this roadmap's existing order, confirmed.

**Done when:** #106-#122 are merged, and the refusals below name who ships
what Omakase refuses.

## M3 - The daily loop

**Delivers:** the Mac app as your daily driver. Today and Focus, the pomodoro
timer (it runs on the Mac and the server records it), session notes and
rating, complete and reschedule, the daily review and shutdown, the menu bar
timer, ⌥⌘N capture from anywhere, notifications, and the offline indicator
with its failed-writes sheet.

**Added by M7:**

- **A reminder model in the API before notifications (R5).** Reminders are
  asked for in four of the five venues M7 read. Defined once on the server,
  each client only schedules them; defined in the Mac app, iOS has to
  define them again.
- **A workload check when planning the day (R4).** Estimated minutes, the
  day's goal hours and the day's classes, summed and shown as a warning -
  Sunsama's threshold, Motion's capacity and Shovel's time cushion are the
  same number. A warning on a plan you placed, not a plan placed for you.
- **Three signals already in the API (R8):** carried-over tasks marked as
  such, the plan date shown apart from the deadline, and focus sessions
  recorded against the block they worked.
- **Energy on the daily review (R10).** One field beside the rating and
  the win of the day; it is the data IDEA §13's energy mapping has no
  other source for.

## M4 - Plan

**Delivers:** the day/week calendar. Drag a task onto a slot to schedule it,
move and resize blocks in 15-minute steps, class occurrences drawn behind.
The largest single screen, so it gets its own milestone, after the app is
already usable. Focus sessions are drawn beside the blocks they worked
(R8), which is the plan-against-actual view the field's users ask for.

## M8 - Repeats and exceptions

**Delivers:** recurring tasks, and a class timetable that survives a real
term: holidays, a cancelled class, and Week A/B rotation.

**Why one milestone:** they are one design. Class occurrences are computed
from a rule and never stored (`study/class-occurrences/`), which is why
they cannot duplicate. A recurring task is the same rule on a task; a
holiday or a cancelled class is the same thing as a completed or moved
occurrence of a task - an exception stored against a computed occurrence.
Super Productivity's recurring bugs come from each client creating
instances; this avoids them by construction (M7, R2).

**Why after M4:** recurring tasks are asked for in all five venues M7 read,
but a repeat is only useful once there is a calendar to repeat on.

## M5 - Parity

**Delivers:** everything else the web client did: projects and workspaces,
Study (semesters, disciplines, class schedules), Settings, the read-only
Calendar.app overlay, and launch at login. After M5 the web client is not
missed.

**Added by M7 (R3, first half):** a test that pins class occurrences across
a daylight-saving change. MyStudyLife and Power Planner users report class
times moving after a clock change; no test here checks that Omakase's
computed occurrences do not.

## M6 - Production

**Delivers:** your data anywhere. Promote `develop` to `main`, make the VPS
serve the API alone (proxy, CORS), point the app at it, and run the parity
checklist.

## Later - iOS, then Android

An iOS target over the same three packages, then Android as its own
Kotlin/Compose app. The API contract and the fixtures are shared.

**Argued against M7's evidence (R9).** A phone app at parity is asked for
in all five venues M7 read, and Shovel and Motion lose users over weak
ones. The order stays: Omakase is built first as its author's daily driver
on a Mac, the three packages already build for iOS 26, and a phone app
before the Mac loop exists would be a second client for a loop no client
has yet. What the evidence changes is what the phone is for when it
comes: reminders and capture first, which is why R5 puts reminders in the
API now.

## Not on the roadmap

Each refusal names who ships it, so it is a decision against a real
alternative. From M7 (`docs/research/2026-landscape.md` §5).

| Refused | Who ships it | Still refused because |
|---|---|---|
| Auto-scheduling | Motion, Reclaim 1.0, Morgen, Amie | Users' top structural complaints are churn and control, and Reclaim 2.0 itself moved to suggesting. A time block has the start and end the user gave it. |
| An AI chat planner | Google (Gemini), Notion Agent, Apple (Siri AI) | Every calendar owner shipped one this quarter, free or bundled. Capture by sentence is not the job and not a fight Omakase can win. |
| Habits and streaks | TickTick, Lunatask | Asked for in one venue of five, and a camp of its own. |
| Grades and GPA, for now | MyStudyLife, Power Planner | Loud in one venue, promised in IDEA §3, and not part of the square. Revisited after M8. |
| Pricing | Everyone | Omakase has no distribution: no App Store, no TestFlight, by the Mac spec. A price is a question for after M6. |

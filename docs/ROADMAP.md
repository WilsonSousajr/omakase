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
| M3-M6 | The daily loop, Plan, Parity, Production | Planned below. |

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

## M3 - The daily loop

**Delivers:** the Mac app as your daily driver. Today and Focus, the pomodoro
timer (it runs on the Mac and the server records it), session notes and
rating, complete and reschedule, the daily review and shutdown, the menu bar
timer, ⌥⌘N capture from anywhere, notifications, and the offline indicator
with its failed-writes sheet.

## M4 - Plan

**Delivers:** the day/week calendar. Drag a task onto a slot to schedule it,
move and resize blocks in 15-minute steps, class occurrences drawn behind.
The largest single screen, so it gets its own milestone, after the app is
already usable.

## M5 - Parity

**Delivers:** everything else the web client did: projects and workspaces,
Study (semesters, disciplines, class schedules), Settings, the read-only
Calendar.app overlay, and launch at login. After M5 the web client is not
missed.

## M6 - Production

**Delivers:** your data anywhere. Promote `develop` to `main`, make the VPS
serve the API alone (proxy, CORS), point the app at it, and run the parity
checklist.

## Later - iOS, then Android

An iOS target over the same three packages, then Android as its own
Kotlin/Compose app. The API contract and the fixtures are shared.

# M5 Parity: design

**Status:** decided 2026-09-27. The run continues through the milestones.
**Milestone:** M5 (`docs/ROADMAP.md`): "everything else the web client did …
After M5 the web client is not missed." **Parent spec:**
`2026-09-25-macos-client-design.md`, L15-21, L81-83, L136-139 and L200-202.

## Parity, defined

The web client, removed in `074d353` (#62), had these pages: login, Focus,
Plan, Review, Projects, Study, Study/<discipline> and Settings. M1-M4
rebuilt login, Focus, Plan and Review. M5 builds the rest, and adds what the
backend gained after the web client went:

| Screen | The web had | M5 builds |
|---|---|---|
| Inbox | none (IDEA §17) | Unscheduled tasks. Schedule, edit, complete. Capture's ⌘⏎ lands here |
| Projects | workspaces, projects, create and delete | Workspaces and projects: create, rename, colour, status, delete. A project's tasks |
| Study | semesters, disciplines, class schedules, study blocks | The same, plus rotation (#126), holidays (#125), and a discipline's study blocks |
| Settings | profile, timezone, week start, pomodoro, goals, log out | The same, plus reminders (#127), launch at login, and the Calendar.app overlay |
| Plan | - | A read-only Calendar.app overlay (EventKit), off by default |

**Not in parity:**
- The web's Morning Plan wizard. It needs its own design.
- Markdown notes.
- Tags UI. The web had a hook and no screen.

## Decisions

- **Library writes are online-only**, as the parent spec says (L136-139):
  workspaces, projects, semesters, disciplines, class schedules, holidays,
  settings and the account.
  - They go through a new `DirectWrites`, which sends the request now,
    applies the reply to the cache, and returns an error message on
    failure. They are never queued.
  - Offline, these controls are disabled, with the tooltip "Needs a
    connection". The online state is the one `SyncIndicator` already uses.
  - The daily loop (tasks, blocks, reviews, sessions) stays on the outbox.
- **The library cache:** `LibrarySync` loads workspaces, projects,
  semesters (all), and the disciplines, class schedules and holidays of the
  **active** semester (L81-83). It runs on launch, on each catch-up, and
  after a direct write. Unscheduled tasks (the Inbox) are loaded with it.
- **Sign out** is a real sign-out:
  - A new `POST auth/logout/` blacklists the refresh token. The blacklist
    app is installed, and nothing used it.
  - The Keychain tokens are cleared.
  - The SwiftData cache and the outbox are erased after a confirmation
    that names how many writes are unsent. The parent spec's L149-151
    rule, that signing in as another account discards the outbox, becomes
    explicit at sign-out.
- **Settings is the macOS Settings scene** (⌘,), not a sidebar item, as a
  Mac app's settings are. The account and sign-out are its first tab.
- **Week start** (`week_starts_on`) and **timezone** are shown in Settings.
  Plan's week follows `week_starts_on`, and the Mac keeps using its own
  timezone for dates (invariant 2). The profile's timezone is displayed,
  not applied.
- **Calendar.app overlay:**
  - It uses EventKit read access, off by default, and is requested on
    first enable.
  - Events are drawn behind blocks, dashed and inkMuted, and never
    draggable.
  - Nothing is written to Calendar.app (L35).
- **Launch at login:** `SMAppService.mainApp`, as a toggle in Settings.

## 1. Backend (PRs U, V)

**U:**
- Task filters: `project`, `workspace` (through the project), `discipline`,
  and `unscheduled=true` (`scheduled_date` is null, templates excluded).
  Each is scoped to `request.user`.
- `POST auth/logout/` takes `{refresh}`, blacklists it, and returns 205. A
  second call is also 205.
- Contract fixtures for:
  - workspaces, projects
  - semesters, disciplines, class schedules, holidays
  - the profile PATCH response and the `me` PATCH response
- CHANGELOG and ARCHITECTURE.

**V, #132:** the DST test. A weekly class expanded across the
October and March transitions keeps its wall-clock start and end. If it
fails, V becomes the fix too.

## 2. Mac data (PR W)

- DTOs and records:
  - Workspace, Project
  - Semester (including rotation), Discipline
  - ClassSchedule (including `rotation_weeks_on`), Holiday
  - ProfileDTO gains `timezone` and `weekStartsOn`
- `APIClient`:
  - list calls for each
  - `unscheduledTasks()`
  - `logout(refresh:)`
- `DirectWrites`: create, update and delete, generic over a path and a
  body. It applies the reply through each entity's upsert, and deletes on
  204.
- `LibrarySync`.
- `Session.signOut(discardingUnsent:)`: revoke, clear the tokens, erase the
  store.

## 3. Mac screens (PRs X, Y, Z, AA, AB)

**X, Inbox:**
- A sidebar item with the unscheduled tasks.
- Each row can be dragged into Plan's column and calendar.
- Actions: Today, Pick a date, Edit (#218), Complete, Delete.
- The count shows as a badge.

**Y, Projects:**
- A two-column screen: workspaces with an All option, then projects as
  cards showing status and task count.
- Create, rename, colour (the web's palette), status and delete. Delete
  asks first.
- A project's detail lists its tasks, reusing the task rows and the
  editor.

**Z, Study:**
- Semesters: create, dates, the active one, rotation weeks and anchor.
- Disciplines: name, code, professor, colour, credits.
- Class schedules: day, times, type, location, active, and rotation
  weeks.
- Holidays: name and range.
- A discipline's study blocks, read-only here.

**AA, Settings:**
- Tabs: Account, General, Focus, Goals, Reminders, Integrations.
  - Account: name, email read-only, Sign out.
  - General: timezone (shown), week start, launch at login.
  - Focus: the four pomodoro numbers.
  - Goals: work and study hours.
  - Reminders: block heads-up minutes or off, shutdown time or off.
  - Integrations: the Calendar.app overlay toggle.
- Each change is a profile PATCH through `DirectWrites`, debounced.

**AB, Calendar.app overlay:**
- An EventKit reader behind a protocol, faked in tests.
- A pure event-to-`CalendarItem` mapping, with a new kind
  `.externalEvent`.
- The Plan grid draws external events behind blocks.

## Verification

- **Tests first:**
  - The backend with two users.
  - `DirectWrites` against the fake API: success, a 400 with its message,
    and offline.
  - `LibrarySync` replaces the active semester's tree.
  - Sign out erases the store.
  - Each screen's model is tested. The views stay thin.
- **In-app:** SMOKE M5, one section per screen. Run it when the screen is
  unlocked and the user is away.
- **ROADMAP:** M5 is built when X-AB are merged.

## PRs

| # | Issue | Contents | After |
|---|---|---|---|
| U | #223 | Task filters, logout, fixtures | - |
| V | #132 | The DST test (and fix) | - |
| W | #224 | Library DTOs, records, `LibrarySync`, `DirectWrites`, sign-out | U |
| X | #225 | Inbox | W |
| Y | #226 | Projects | W |
| Z | #227 | Study | W |
| AA | #228 | Settings (account, sign out, launch at login) | W |
| AB | #229 | Calendar.app overlay | M4 |

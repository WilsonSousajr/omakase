# The native macOS client — design

Issue #72. Agreed in brainstorming on 2026-09-25. It covers the first native
client and the API changes it needs. iOS and Android are a later epic, and
this design constrains them only where noted.

## Intent

**Who it's for.** One user, the author, as a daily driver. It replaces the
removed Next.js web client (#62). There is no App Store, beta group or public
distribution in this design.

**What success is.** The Mac app replaces the web app completely:

- It reaches **full parity**: plan, focus, review, projects, study and
  settings.
- It adds four things only a native app can do:
  - an always-there menu bar timer
  - capture from anywhere with a global hotkey
  - working offline through the daily loop
  - system integration: notifications, Calendar.app and launch at login
- It uses Apple's **Liquid Glass** design language, with a visual identity
  designed fresh for it.

**Constraints.**

| Constraint | Consequence |
|---|---|
| Liquid Glass | SwiftUI (and AppKit where needed), macOS 26 minimum. Rules out Compose Multiplatform for the Apple apps. |
| Free Apple ID, no paid membership | Local signing on this Mac. No notarization, no TestFlight, no App Sandbox. CI builds and tests unsigned. |
| Offline focus, not offline-first | An outbox of queued writes; no two-way sync, no change tracking, no tombstones. |
| Local backend first | The API base URL is a setting. The app runs against `docker-compose` until M6 moves it to the VPS. |
| Later iOS app | Everything outside the app target is platform-neutral Swift packages. |

**Out of scope for v1:** writing to Calendar.app, Focus-mode filters,
Handoff, Spotlight indexing, widgets, push notifications, Sign in with Apple
(which needs a paid membership), and client-generated ids on the API.

## Structure

```
apps/apple/
  Omakase.xcodeproj           app targets only: OmakaseMac (OmakaseiOS later)
  Packages/
    OmakaseAPI/               REST client, DTOs, Keychain tokens. No UI, no SwiftData.
    OmakaseStore/             SwiftData models, the outbox, the sync worker.
    OmakaseFeatures/          SwiftUI screens and view models, by feature.
  OmakaseMac/                 app entry, MenuBarExtra, global hotkey, notifications.
  Fixtures/                   API response bodies written by the backend's tests.
  gate.sh                     the Apple gate, step for step what CI's apple-gate runs.
```

**Dependencies run one way: `OmakaseFeatures → OmakaseStore → OmakaseAPI`.**
The app target wires them together. Package manifests make a reverse import a
compile error, and a gate test asserts the manifests declare only these
edges.

- **OmakaseAPI** is the only code that knows HTTP, JSON or endpoint paths. It
  exposes typed async functions behind an `APIClient` protocol, for example
  `func tasks(on day: Date) async throws -> [TaskDTO]`. It owns the Keychain
  token store and refresh-on-401: refresh once, retry once, otherwise report
  signed out. The client is written by hand, because there is no OpenAPI
  schema and the surface is about 20 endpoints.
- **OmakaseStore** is the UI's source of truth. Views read SwiftData through
  `@Query`. Writes go through store functions. Nothing in Features calls the
  API.
- **OmakaseFeatures** holds Today/Focus, Plan, Review, Projects, Study,
  Settings and Capture. Everything in it is shared with iOS, so macOS-only
  chrome stays in the app target.

## Data flow

### Reads

The sync worker fetches the **windows the UI shows** and upserts them into
SwiftData:

- today
- the visible calendar week, plus that range's class occurrences
- the active semester's tree
- workspaces and projects
- the profile and preferences

It does this on launch, on reconnect, when the visible window changes, and
every 5 minutes while the app is active. In any window it fetches, the server's
state replaces the cache, **except** for items that have queued outbox
entries, which keep their local state until those entries are sent. Offline,
views show the last fetch.

Every day-shaped request sends the client's own date as `?date=` (AGENTS.md
invariant 2).

### Writes that work offline: the daily loop

- Pomodoro: start, pause and finish locally. The finished session is posted
  to `/pomodoro/sessions/`.
- Complete or uncomplete a task or study block.
- Quick capture, which creates a task.
- Reschedule: PATCH `scheduled_date` to tomorrow, a chosen date, or `null`.
- Time block session notes and rating.
- The daily review: rating, win, shutdown.

Each is **one SwiftData transaction** that updates the local model and
appends an `OutboxEntry`:

| Field | Meaning |
|---|---|
| `sequence` | Monotonic order. Entries are sent strictly in this order |
| `method`, `path`, `body` | The request, with placeholder ids where they apply |
| `idempotencyKey` | A UUID created with the entry and never regenerated |
| `createdAt`, `attempts`, `lastError` | For backoff and for the failed-writes sheet |
| `state` | `pending`, `inFlight` or `parked` |

### Replay

One entry at a time, in `sequence` order:

| Response | Action |
|---|---|
| 2xx | Delete the entry, write the server's copy into the store, and map a placeholder id to the real one |
| Network error, timeout, 5xx, 429 | Keep the entry and retry it after exponential backoff (1 s doubling, capped at 5 min) |
| 401 | Refresh the token once, then retry. If refresh fails, pause the queue and ask the user to sign in |
| Other 4xx | **Park** the entry with the server's message, and continue with later entries unless they reference it |

**Placeholder ids.** An item created offline gets a local id with a
`local-` prefix. When its create entry succeeds, every queued entry whose
path or body contains that placeholder is rewritten to the server's UUID
before it is sent. An entry that references a placeholder whose create was
parked is parked too, with that reason.

**Writes outside the daily loop** are online-only: workspaces, projects,
semesters, disciplines, class schedules, tags, settings, and creating or
moving time blocks in Plan. Offline, those controls are disabled, and a
tooltip says a connection is needed. They are never queued.

### Auth

1. `ASWebAuthenticationSession` runs Google OAuth with PKCE, using a macOS
   OAuth client ID. That client ID is not a secret.
2. The resulting Google ID token is posted to the existing
   `POST /api/v1/auth/google/`.
3. The returned JWT pair is stored in the Keychain.
4. A 401 triggers one refresh through `auth/token/refresh/`. A failed refresh
   signs the user out but keeps the outbox, which replays after the next
   sign-in, when the account is the same one. Signing in as a different
   account discards the outbox after a confirmation dialog.

## API changes (backend, M1)

Each change gets its own issue, is written test-first, and is argued as a
contract change (invariant 8).

1. **Multiple Google audiences.** `GOOGLE_CLIENT_ID` becomes
   `GOOGLE_CLIENT_IDS`, a comma-separated list. `/auth/google/` accepts an ID
   token whose `aud` is any of them. The single-ID variable is still read, for
   one release, so the VPS keeps working.
2. **`Idempotency-Key` on the outbox's create endpoints.** These are
   `tasks/`, `pomodoro/sessions/` and `stats/reviews/`, plus any PATCH the
   outbox sends, which is naturally idempotent and so only needs the key
   tolerated. A request with a key already seen for that user returns the
   stored status and body instead of acting again. A new `IdempotencyRecord`
   model stores `(user, key)` unique, the method, path, status code, response
   body and creation time. Records older than 7 days are deleted by a
   management command. The same key with a different method or path is a 422.
3. **#69's single date parser**, already filed, so every `?date=` the app
   sends is parsed and rejected in one place.

## The app on macOS

- **Main window**: a `NavigationSplitView` with a sidebar (Today, Plan,
  Review, Projects, Study, Settings), a content column and an inspector for
  the selected item. Standard containers draw Liquid Glass themselves on
  chrome. Custom floating surfaces (the timer and the capture panel) use
  `glassEffect` inside a `GlassEffectContainer`. Content (lists and the
  calendar grid) stays opaque.
- **Plan**: a custom SwiftUI day/week grid.
  - Drag a task or study block onto a slot to create a time block and set
    `scheduled_date`.
  - Drag a block to move it; if the day changes, the parent's
    `scheduled_date` changes too.
  - Drag a block's bottom edge to resize it in 15-minute steps.
  - Class occurrences render behind blocks as read-only.
  - Overlaps warn before saving, as the web client did.
- **Menu bar**: a window-style `MenuBarExtra` with the running timer
  (start/pause/skip), the current and next block, today's remaining tasks and
  a capture field. It reads the same store.
- **Global capture**: a configurable hotkey (default ⌥⌘N) registered in the
  app target. It opens a floating glass panel over any app, and Enter saves
  through the store, so capture works offline.
- **Notifications** (`UserNotifications`): pomodoro transitions, and a
  configurable heads-up before the next block.
- **Calendar.app** (EventKit): a read-only overlay on Plan. It is off by
  default and requested on first enable.
- **Launch at login**: `SMAppService`, a toggle in Settings.
- **Offline indicator**: a toolbar glyph showing online or offline, the
  queued-write count, and, when something is parked, a sheet listing failed
  writes with the server's message, with Retry and Discard for each.
- **The timer runs on the Mac.** The running pomodoro is persisted in the
  store, so it survives a quit. The server receives the finished session as a
  record and never drives the clock.

**Visual identity is designed fresh in M2.** Palette, type scale, glass
tinting and the Today/Focus layout are explored as mockups before the M3
screens are built, and the chosen tokens are recorded in
`docs/design-system-apple.md`. `docs/design-system.md` stays as the web
record.

## Testing and the Apple gate

`apps/apple/gate.sh` and a CI job, `apple-gate`, run the same steps in the
same order on `macos-latest` with Xcode pinned exactly. A test asserts the
two lists match, as `tools/tests/test_gate_workflow.py` does for the backend.

| Step | Limit |
|---|---|
| `swift format lint --strict` | - |
| `swiftlint --strict` (pinned) | function body 20 lines, cyclomatic 10, nesting 2, file 500 lines, no `print` |
| manifest test | only `Features → Store → API` |
| `swift test --enable-code-coverage`, per package | - |
| coverage (llvm-cov JSON) | ≥ 90% on OmakaseAPI and OmakaseStore |
| C.R.A.P. (`crapcheck` reading llvm-cov JSON) | < 12 |
| `xcodebuild build`, unsigned | the app target builds |

**The limits start at their targets, not as ratchets**, because this code is
born under the gate. OmakaseFeatures' SwiftUI view bodies are excluded from
coverage, with the reason written beside the exclusion; its view models are
not excluded.

**What is tested:**

- **OmakaseAPI**, against a `FakeHTTPTransport`: decoding of every DTO, the
  refresh-on-401 flow, and error values that name the offending field.
- **OmakaseStore**, against an in-memory SwiftData container and a
  `FakeAPIClient`:
  - outbox order
  - backoff
  - park-on-4xx, and parking of dependent entries
  - placeholder rewriting
  - the one-transaction write
  - replay after a simulated crash between enqueue and send
- **Contract fixtures.** Backend tests write the response body of every
  endpoint the app uses into `apps/apple/Fixtures/`. The Swift DTO tests
  decode those files, so a change that breaks the client's decoding fails in
  the same PR. A backend test fails if a fixture is stale.
- **Every bug gets a failing test first**, named with its issue number
  (AGENTS.md).

**Each milestone ends with the real app against the real local stack**, run
through a written checklist: sign in, go offline, run and finish a pomodoro,
complete a task, capture one, reconnect, and confirm the server has all
three.

## Milestones

| | Milestone | Delivers | Usable as |
|---|---|---|---|
| M0 | Groundwork | #63-#66, then #69 | - |
| M1 | Foundation | The API changes above; the project, three packages and `apple-gate`; sign-in; read sync; the outbox engine; a plain Today list | Sign in, see today, read offline |
| M2 | Identity | The fresh visual design as mockups, then tokens applied to the shell | The app has its look |
| M3 | The daily loop | Today/Focus, timer, notes and rating, complete and reschedule, review and shutdown, menu bar, capture hotkey, notifications, offline indicator | The daily driver |
| M4 | Plan | The day/week calendar with drag, move, resize and class occurrences | Weekly planning |
| M5 | Parity | Projects and workspaces, Study, Settings, EventKit overlay, launch at login | Replaces the web app |
| M6 | Production | Promote `develop` to `main`, make the VPS API-only, point the app at it, run the parity checklist | Data anywhere |
| Epic | iOS, then Android | An iOS target over the same packages; Android as its own Kotlin/Compose app | Later |

## Housekeeping (confirmed with the design)

1. Triage the 32 open issues labelled `frontend` against this roadmap. Web-only
   ones are closed with a pointer to #62, and features the Mac app will have
   are relabelled with their milestone and `area:apple`. The triage table is
   shown before any bulk `gh` command runs.
2. Migrate the open issues from phase, priority and effort labels to type,
   `M<n>` and `area:*` in that same pass, then delete the old labels.
3. Protect `main`:
   - Required checks: `gate` now, and `apple-gate` once it exists.
   - No force-push and no deletion.
   - Enforced for admins too.

   `deploy.yml` deploys every push to `main`, so this is the only safeguard
   between a mistake and production.
4. Merge the M0 stack (#67 → #68 → #70 → #71) in order, with approval.

## Risks

- **SwiftData maturity.** Migration and query limits have bitten early
  adopters. Mitigation: OmakaseStore hides SwiftData behind store functions,
  so GRDB (approach C) could replace it inside one package.
- **A custom calendar is the largest single piece of UI.** It has its own
  milestone, M4, and the app is already the daily driver before it lands.
- **Free signing.** Builds come from Xcode on this Mac, and there is no
  auto-update. Moving to Developer ID later adds a signing step to
  `apple-gate` and changes nothing else.
- **Idempotency storage grows with use.** A 7-day expiry and one row per
  queued create keep it small for a single user.

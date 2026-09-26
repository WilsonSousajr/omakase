# M3.5 Capture and offline: design

**Status:** decided 2026-09-26 under the milestone-checkpoint rule. The user
reviews M3 as a whole when M3.6 lands.
**Milestone:** M3, "The daily loop". The parent spec,
`2026-09-25-macos-client-design.md`, gives capture at L98 and L195-197, the
offline indicator at L203-205, and the replay rules at L122-139.

## What exists

- **`TaskWrites.capture(title:day:)`** creates a `local-` task and queues
  `task.create`. Nothing in the UI calls it.
- **The outbox parks every 4xx that isn't a 401**, with the server's
  message in `lastError`. Parking a create also parks the entries that
  depend on it.
- **Nothing can list, count, retry or discard an entry.** `pendingEntries()`
  is private.
- **`OutboxWorker.drain()` returns `.waiting(until:)`, and
  `SyncCoordinator` drops it.** A write in backoff is therefore only retried
  at the next reconnect, the next 5-minute tick, or the next write.
- **`Reachability` only fires `onOnline`.** Nothing publishes whether the app
  is online.
- **No hotkey or panel code exists.** There are no third-party
  dependencies, and the app is not sandboxed.

## Decisions

- **The hotkey uses Carbon's `RegisterEventHotKey`, wrapped in the app
  target.**
  - It needs no Accessibility permission, which an `NSEvent` global
    monitor would.
  - It needs no dependency, and a hotkey library would be the first
    third-party package.
  - The default is ⌥⌘N. The hotkey becomes configurable in M5's Settings.
- **The panel is an `NSPanel`** with the floating level, full-size content,
  a transparent titlebar, and `canJoinAllSpaces`. It is hosted with
  SwiftUI's `CapturePanelView`, from the mockup, turned into a real view
  over a `CaptureModel`.
  - Enter saves and closes, and Escape dismisses.
  - An empty title saves nothing.
- **Where a capture lands:**
  - **Today by default.** No Inbox screen exists yet, so a task with no
    date would vanish from every screen until M5.
  - **⌘⏎ saves to the Inbox**, which means no date.
  - The panel's footer shows which one Enter will do.
- **Capture only goes through the store** (`TaskWrites.capture`), so it works
  offline. The app is focused only when the panel opens. The panel is
  closed, never hidden, so there is no stale draft.
- **The outbox gets a small public surface in OmakaseStore:**
  - `OutboxStatus`: pending count, parked entries, and the next attempt.
  - `retry(sequence)`: un-parks one entry, resets its attempts and backoff,
    and un-parks the entries parked because they depend on it.
  - `discard(sequence)`: deletes the entry and its dependents.
    - When the entry was a create, it also deletes the local record that
      the create made.
    - For a patch, the next refresh restores the server's copy, because
      `DayApply` stops protecting a record once no write is pending for it.
- **Backoff wakes itself.** When a drain returns `.waiting(until:)`, the
  coordinator schedules one catch-up at that time, replacing any earlier
  one.
- **The indicator lives in the window toolbar** and uses the system's glass,
  untinted:
  - online and empty: a quiet `checkmark.icloud`
  - offline: `icloud.slash`
  - queued: the count
  - parked: `exclamationmark.icloud`, which opens the failed-writes
    sheet

  The sheet lists each parked write, with a readable label from its `kind`
  and subject, the server's message, and Retry and Discard. It is
  monochrome, and shu is never used. The value it renders is a pure
  `SyncIndicator` in Features. `Reachability` publishes `isOnline`.

## PRs

| # | Issue | Contents | Depends on |
|---|---|---|---|
| F | #184 | OmakaseStore: `OutboxStatus`, retry, discard, the backoff wake in `SyncCoordinator`, and tests against the in-memory store | - |
| G | #185 | Features: `SyncIndicator` and `FailedWritesView`. Mac: `Reachability.isOnline`, the toolbar item, the sheet | F; #177 and #179 merged, because of `AppServices` |
| H | #186 | Features: `CaptureModel` and `CapturePanelView`. Mac: the Carbon hotkey, the `NSPanel`, wiring to `TaskWrites.capture`. `SMOKE.md` M3.5 and ROADMAP | #177 and #179 merged |

## Verification

- **Store:**
  - Parking, then `retry`, sends the entry again.
  - `discard` of a parked create removes its local task and its
    dependents.
  - `OutboxStatus` counts pending and parked entries correctly.
  - The backoff wake calls `catchUp` once, at `nextAttemptAt`, tested with
    an injected scheduler.
- **Features:**
  - `SyncIndicator` covers each state.
  - `CaptureModel` checks that an empty title doesn't save, that Enter
    saves for today and ⌘⏎ saves to the Inbox, and that the draft clears
    after a save.
- **In the real app:**
  1. Stop the backend (`docker-compose stop backend`). The indicator goes
     offline.
  2. Press ⌥⌘N over another app, and capture two tasks. The count shows 2.
  3. Start the backend. The count drains to 0, and both tasks exist on the
     server.
  4. Force a park, for example by PATCHing a task deleted on the server.
     The sheet appears, and Retry and Discard work.

**Done when:** F-H are merged with both gates green, and the M3.5 smoke run
passes in the real app.

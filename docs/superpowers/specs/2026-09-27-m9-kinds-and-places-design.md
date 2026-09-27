# M9 Kinds and places: design

**Status:** decided with the user 2026-09-27 (#252).
**Milestone:** M9 (`docs/ROADMAP.md`).
**Parent spec:** `2026-09-25-macos-client-design.md`.
**Design record:** `docs/design-system-apple.md`. Section 11 lists what M9 changes in it.

## Why

After M5 the Mac app does everything the web client did, but three things
remain wrong. They were measured in the running app and the code on
2026-09-27.

- **Creating a task can't be found.**
  - ⌥⌘N is the only way in, globally and under File › Capture Task…
  - No button, toolbar item or ⌘N opens the panel. Only the Inbox's empty
    state mentions the shortcut.
  - ⌘N is SwiftUI's default "New Window".
- **A task can't say what it is for.**
  - The backend models this already:
    - `Task.area` is work, personal or study (`backend/tasks/models.py:16-19`, `:111`).
    - A task has an optional `project` and an optional `discipline`.
    - `TaskFilter` has `?project=`, `?discipline=`, `?area=` and `?is_completed=` (`backend/tasks/views.py:33-57`).
  - The Mac throws all three away:
    - `TaskRecord` does not store them.
    - Capture sends only `{title, scheduled_date}`, so every task it creates is `area=work` with no parent.
- **The window looks unfinished.**
  - The sidebar is six flat rows that mix the day's loop (Plan, Focus, Review) with places (Inbox, Projects, Study). About 80% of it is empty, and it has no footer, no create button and no sign of a running timer.
  - Calendar blocks are all grey: `CalendarItem.block(_:titles:)` passes no tint, although the design record says blocks wear their source's colour.
  - The app has no animation at all.

## Decisions

These were settled with the user, in this order:

1. **A task has a kind and an optional parent.** The kind is **Work**, **Study** or **Life**. Life is the wire value `personal`, so the API does not change.
   - A project makes a task Work, and a discipline makes it Study. The kind is derived in one place (§1).
   - IDEA §17's rule, "no categorization required at capture time", holds:
     - the kind is one optional keystroke;
     - it defaults to the last one used;
     - the parent is optional.
2. **The sidebar is "the day and your places"** (§6):
   - a live now strip;
   - Focus, Plan, Review, Inbox;
   - Work (its projects), Study (the current semester's disciplines), Life;
   - a footer with New Task, the account and sync.
3. **One capture panel, which knows where you are** (§4).
   - ⌘N, the sidebar's button and the toolbar's ＋ open the same panel as ⌥⌘N.
   - The panel is seeded from the screen you are on.
   - Drawing on an empty calendar slot opens it with that day and time.
4. **The visual pass:**
   - kind colours (§2);
   - a native toolbar and one header per screen (§7);
   - calmer task rows (§8);
   - calendar blocks that wear their kind, plus draw-to-capture (§9).
5. **Motion, the Apple way** (§10):
   - springs, symbol effects and numeric content transitions;
   - named tokens;
   - nothing moves when Reduce Motion is on.

**No backend or contract change.** `POST tasks/` uses `TaskSerializer`, where `area`, `project` and `discipline` are writable. `_validate_ownership` (`views.py:100-113`) rejects a parent the user does not own.

The list endpoint is enough for a place's tasks, with one caveat: `GET tasks/?project=` also returns series templates and skipped rows. The client drops them (§5).

## 1. Kinds and parents in the store (S1)

`OmakaseStore/TaskFiling.swift` holds the kind and its derivation:

```swift
public enum TaskArea: String { case work, study, life = "personal" }   // unknown → .work
public enum TaskParent: Hashable { case project(String), discipline(String) }
public struct TaskFiling: Hashable {
    public let area: TaskArea
    public let parent: TaskParent?
    /// The only place the kind is derived: a discipline is Study, a project
    /// is Work, otherwise the chosen area.
    public init(area: TaskArea, parent: TaskParent?)
}
```

The derivation lives in the store, because the store must send a consistent body. The screens and the sync code read it from there.

When the server holds an inconsistent row, for example a discipline with `area=work`, the task shows as Study. The backend doesn't enforce the match; see "Not in M9".

`TaskRecord` gains three properties:
- `area: String = "work"`
- `projectID: String?`
- `disciplineID: String?`

It also gets a computed `filing`.
- **Defaults:** the properties carry default values, so SwiftData migrates the existing store without a hand-written migration. `kanbanStatus` set this precedent.
- **Why raw strings:** `#Predicate` filters on them, as it filters on `priority` today.
- **Where the values come from:** `init(dto:)` and `apply(_:)` copy them from `TaskDTO`, which already decodes them. DaySync, RangeSync, LibrarySync and TaskHandler then fill them in with no further change.

**Writes:**
- `TaskWrites.capture(title:day:filing:)`: `CaptureBody` gains `area`, `project` and `discipline`. A nil parent is left out of the create body.
- `TaskEdit.filing`: when set, the PATCH sends all three keys, with explicit nulls. Moving a task from a project to a discipline is then one consistent write.
- A parent comes from the library cache, which is only written online (M5). So a parent id is never a `local-` id and never waits on the outbox.

**Contract fixture, test only:** `task_create.json`, a `POST tasks/` with `area=study` and a discipline. It is written by `backend/tools/tests/test_contract_fixtures.py` and decoded in the Swift DTO tests.

## 2. Kind colours and motion tokens (S2)

`OmakaseFeatures/Design/KindTint.swift` holds the kind colours. Measured on 2026-09-27:

| Kind | Dark | Light | On `background` (dark / light) | Closest colour, ΔE76 (dark / light) |
|---|---|---|---|---|
| Work, verdigris | `#3FA7A0` | `#1E7F78` | 6.40 / 4.39 | matcha, 24.5 / 23.3 |
| Study, wisteria | `#A48BD0` | `#6E58A6` | 6.35 / 5.30 | indigo, 21.5 / 26.4 |
| Life, dusty rose | `#C98AA0` | `#9E5874` | 6.74 / 4.66 | Study (dark) 30.5; priority low (light) 32.4 |

**Why these hues:**
- The warm hues were taken: shu means focus and now, and amber, orange and red mean priority.
- Matcha and indigo are the timer's break phases.
- So the kinds come from the cool and muted colours.

**Tests (`KindTintTests`):**
- Every kind colour is ≥ 3:1 on `background` as a mark, in both appearances (WCAG 1.4.11).
- Each is ΔE76 ≥ 20 from shu, matcha, indigo, the four priority colours and the other kinds, so a later palette change cannot make two meanings look alike.
- The Lab and ΔE maths is a test helper and does not ship.

**`KindTint.mark(for:parentHex:)`** is the colour a task or block shows:
- a project's or discipline's own colour, if it reaches 3:1 in both appearances;
- otherwise its kind's colour.

Colour here is data, so it survives the monochrome rule (Principle 3).

**`OmakaseFeatures/Places/TaskAreaPresentation.swift`:** each kind's title and SF Symbol (`briefcase`, `graduationcap`, `leaf`), and the digit that picks it in capture.

**`OmakaseFeatures/Design/Motion.swift`:**

| Token | Animation | Used for |
|---|---|---|
| `select` | `.snappy(duration: 0.22)` | chips, selection, toggles |
| `layout` | `.smooth(duration: 0.35)` | panels opening, List ⇄ Kanban, rows arriving |
| `complete` | `.bouncy` | a task being completed |

- `Motion.resolved(_:reduceMotion:) -> Animation?` returns nil when Reduce Motion is on.
- `Motion.digits(reduceMotion:)` returns `.numericText()` or `.identity`.
- The `.motion(_:value:)` modifier reads `accessibilityReduceMotion` and applies both of the above.
- `MotionTests` pins that mapping; both `Animation` and `ContentTransition` are Equatable.
- A SwiftLint custom rule, `raw_animation`, rejects `withAnimation(` and `.animation(` outside `Motion.swift`, so no screen can bypass Reduce Motion.
- Tokens are statics on plain enums, never on a View (#233).

## 3. The window moves into Features (S3)

A refactor with no visible change. Every later slice builds on it.

- **`OmakaseFeatures/Shell/MainWindowView.swift`** owns the `NavigationSplitView`.
  - The app target passes it a `ScreenModels` bundle and an `openCapture(CaptureContext)` closure.
  - The target keeps only the wiring.
- **`SidebarSelection`** is either `.item(SidebarItem)` or `.place(TaskPlace)`. It is `RawRepresentable`, with raw values such as `focus` and `place.discipline.<id>`.
  - It is saved with `@SceneStorage("omakase.sidebar")`, so relaunching returns you to where you were.
  - If the saved place has been deleted or archived, the selection falls back to Focus.
- `OmakaseMacApp`'s `@State section` goes. It was App-level state, so every window shared one sidebar selection.
- `handle()` refreshes the Calendar.app overlay using `PlanModel.isShowing` instead.
- `SidebarItem` and `SidebarRowView` move into `Shell/`.

## 4. Capture (S4, S5)

`CaptureContext { filing: TaskFiling?, day: String?, slot: PlanPlacement? }`
is what the panel opens with. A nil `filing` means the remembered kind.

| Opened from | Seeded with |
|---|---|
| ⌥⌘N in another app | the last kind; ⏎ Today |
| ⌘N or ＋ on Focus, Review or the Inbox | the last kind; ⏎ Today |
| ⌘N or ＋ on Plan | the last kind; ⏎ the day shown |
| ⌘N or ＋ on a project's or a discipline's list | Work ▸ that project, or Study ▸ that discipline |
| ⌘N or ＋ on Life | Life |
| A slot drawn on Plan (§9) | the last kind; ⏎ that day and time, a task and its block |

**The panel:**
```
┌──────────────────────────────────────────────────┐
│ Read chapter 4 of Axler                          │
│                                                  │
│ (Work) (Study●) (Life)     ▸ Linear algebra      │
│ ⌘1–3 kind · ⏎ Today · ⌘⏎ Inbox · ⎋ dismiss       │
└──────────────────────────────────────────────────┘
```

**Keys:**
- **⌘1, ⌘2, ⌘3** pick Work, Study, Life. They use hidden buttons, the same mechanism as today's ⌘⏎ and ⎋.
  - Tab stays with the text field. Chips can take focus only when Full Keyboard Access is on, which is off by default.
  - ⌘P stays Print.
  - ⌘1–3 are not bound in the main window in M9, so they never compete.
- **The parent** is a `Menu` chip listing the current kind's places. It is hidden for Life.
  - Choosing a parent sets the kind.
  - Changing the kind clears a parent that no longer fits.
- **⏎** saves to the context's destination: the slot, then the day, then Today. **⌘⏎** always saves to the Inbox.
- The hint names what ⏎ does in this context.

**The last kind** is stored in UserDefaults as `omakase.capture.area`, beside `omakase.calendarOverlay`. It is written on save.

**How context reaches the panel:**
- `MainWindowView` publishes the current context with `.focusedSceneValue(\.newTaskContext, …)`.
- `CaptureCommands` replaces `.newItem`: File › New Task ⌘N reads the context with `@FocusedValue` and calls `GlobalCapture.show(context:)`. File › Capture Task… ⌥⌘N stays.
- The sidebar's button and the toolbar's ＋ call `openCapture`.
- The panel is its own `NSPanel` root, with none of the window's environment or tint (#214). So it is handed a `PlaceDirectory`, loaded from the library cache when it opens:
  - active projects, grouped by workspace;
  - the current semester's active disciplines.

**Re-filing existing tasks (S5).** Every task captured so far is Work with no parent. Without a way to re-file, Study and Life would open empty.
- The task editor gets the same kind chips and parent menu, through a shared `KindChipsView`.
- The Inbox's action menu gets "File under ▸".

## 5. A place's tasks (S6)

A place is a project, a discipline or Life: `TaskPlace` in the store, with a `filing` and one shared `openTasksPredicate`.

- **API:** `APIClient.openTasks(PlaceTasksQuery)` calls `GET /api/v1/tasks/?<project|discipline|area>=…&is_completed=false`, following all pages.
- **`PlaceSync`** follows `LibrarySync`'s pattern. It runs when a place is shown and on each catch-up while one is shown.
  - Series templates (`recurrence` set, `series` null) and skipped rows are dropped.
  - Rows with no pending write are upserted.
  - A cached open row of that place that is missing from the answer is removed, except in these cases:
    - it is pending;
    - it is `local-` or `occ-`;
    - it is scheduled today or carried over, because DaySync owns those.
  - Offline, the cache is kept.
- **Screens:**
  - The Inbox's model and rows become Triage, in one refactor commit (`InboxModel` → `TriageModel`, and its row and action views). The Inbox and the place lists sort and act on tasks the same way.
  - `PlaceListModel`, `PlaceSections` and `PlaceTasksView` show a place's open tasks under Overdue, Today, Upcoming and No date.
- **Repeating tasks** appear through their materialized rows only. Virtual occurrences are the calendar's.

## 6. The sidebar (S7)

```
┌────────────────────────────┐
│ ◔ 18:42  Outline thesis    │ now strip
│                            │
│ ◎ Focus                 5  │
│ ▦ Plan                     │
│ ☾ Review                   │
│ ▭ Inbox                 3  │
│                            │
│ Work                    9  │ → Projects
│   ▌ Omakase             7  │ → its list
│   ▌ Lab                 2  │
│ Study                   5  │ → Study
│   ▌ Linear algebra      4  │
│   ▌ Thesis              1  │
│ Life                    2  │ → its list
│                            │
│ ＋ New Task           ⌘N   │
│ ◯ you@…        ☁ Synced    │
└────────────────────────────┘
```

**The now strip** (`NowStrip`, a pure mapping, drawn by `SidebarNowStripView`):
- While a phase runs, it shows the phase's ring in its colour, the countdown and the task.
- While paused, the same, dimmed.
- When idle, it shows the next block, reusing `MenuBar.nextBlock` and `SessionBlock.Slot`.
- Otherwise it shows nothing.
- Clicking it opens Focus with that task selected.
- Only the strip observes the timer's tick, so the sidebar does not redraw every second.

**The day:** Focus, Plan, Review and Inbox. Focus leads because the app opens on it. The Inbox keeps its badge.
- Plan led until now, pinned by `SidebarItemTests`.
- That test changes with this decision, and its commit says so.

**Places** (`SidebarPlaces`):
- **Work:** active projects, grouped under workspace headers when there is more than one workspace.
- **Study:** the active semester that contains today (else the latest active one), then its active disciplines.
- **Life.**
- A kind's header opens its management screen (Work opens Projects, Study opens Study). Each place opens its list (§5).
- Counts are open tasks and change with `.numericText`.

**The footer** (`SidebarFooterView`):
- ＋ New Task ⌘N.
- The account (`SettingsModel.email`), which opens Settings through `SettingsLink`.
- `SyncIndicatorView`, moved here from the toolbar.

## 7. Toolbar and header (S8)

Every screen puts its controls in the window's toolbar and names itself with `navigationTitle` and `navigationSubtitle`. Content starts at the top of the detail column, with no header row of its own.

| Screen | Title / subtitle | Toolbar |
|---|---|---|
| Focus | Focus / Monday 27 September | List ⇄ Kanban (principal), ＋ |
| Plan | Plan / 21–27 Sep 2026 | ‹ Today › (navigation), Day ⇄ Week (principal), Calendar, ＋ |
| Review | Review / the day | ＋ |
| Inbox | Inbox / n to triage | ＋ |
| A place | its name / its kind | ＋ |
| Projects | Projects / the workspace | New Project…, ＋ |
| Study | Study / the semester | ＋ |

- `PlanHeaderView` and Focus's header row go.
- The workload banner stays in Focus's content, because it is a message, not a control.
- A pure long-day formatter joins `DayString`.

## 8. Rows (S9)

- **A kind mark on every row:** a kind-coloured mark and the parent's name, for example `▌ Linear algebra`. Kinds without a parent show the kind's name.
  - It appears on `TaskRowView`, `PlanTaskRowView`, the Kanban card and the menu-bar panel.
  - A place's own list leaves it out, because it would repeat the title.
  - It is resolved through a `PlaceDirectory` in the environment.
- **Priority** shows only when it says something: Low, High or Urgent. The default Medium pill goes (`PriorityMark.showsInRow`).
  - In the 2026-09-27 window, all 9 rows carried a pill, 3 of them Medium.
- **Section labels** become sentence case, semibold, `inkMuted` and untracked (`TypeScale.sectionLabel`).
  - The tracked all-caps label was the web's signature. It is also the most common tell of a generated interface, and it shouted over the content.
  - `TintsTests.sectionLabelIsUppercasedAndMuted` becomes a test of the new rule.
- **Study in Focus:** the "Study today" capsules move from `Palette.indigo`, the long-break colour, to the Study colour.

## 9. Calendar (S10, S11)

**Blocks wear their kind (S10):**
- `CalendarItem.block(_:parents:)` takes its tint from `KindTint.mark`. A study block takes its discipline's colour.
- `CalendarItemView` draws a 3-pt bar and a faint fill of that colour on the opaque `surface`, the title, a time line when the block is tall enough, and the kind's glyph.
- Class occurrences keep their dashed outline and `book`.
- Today's column is lifted: a faint surface and an emphasised header.

**Draw a slot to capture (S11):**
- **The gesture:** dragging on an empty part of a day column draws a dashed ghost.
  - It snaps to 15 minutes, is at least 15 minutes long and is clamped to 06:00–23:00 (`PlanDrop.slot`).
  - A click alone does nothing.
  - It uses `DragGesture(minimumDistance: 4)`, so tap-to-deselect and `.dropDestination` keep working.
- Releasing opens capture with that slot. ⏎ creates the task and its block in one `coordinator.write`:
  - First `task.create` (with the slot's day, so no reschedule is queued), then `block.create`, which names the `local-` id.
  - `OutboxWorker` rewrites the id when the task is accepted.
  - A parked task create parks its block (`OutboxRules.dependents`).
- **No overlap question** for a drawn slot: you drew it there.
- **Two existing bugs this makes reachable,** each fixed after its failing regression test:
  - `TaskHandler` doesn't re-point `TimeBlockRecord.taskID` and `SubtaskRecord.taskID` from the `local-` id to the server's id.
  - Deleting an unsent capture (`TaskWrites.delete`) leaves its local blocks behind.

## 10. Motion (S12)

Motion answers what you did. Nothing moves by itself, except the timer and the now strip, which are clocks.

| Moment | Motion |
|---|---|
| Completing a task | the circle becomes `checkmark.circle.fill` (`.symbolEffect(.replace)`), a `complete` bounce, and the row leaves with `layout` |
| Timer digits, the now strip, sidebar counts | `.contentTransition(.numericText())` |
| A kind chip in capture | the selection glides between chips (`glassEffectID` in the panel's `GlassEffectContainer`) |
| Plan's detail panel, List ⇄ Kanban | `layout` transitions |
| Drawing a slot | the ghost follows the pointer live; the block settles with `select` |

- **The completion toggle** is `CompletionToggleStyle`. It keeps the toggle's accessibility traits, and the design record notes that it replaces the system checkbox.
- **Reduce Motion:**
  - Every token resolves to no animation.
  - `.symbolEffectsRemoved(reduceMotion)` sits at the roots of the main window and the capture panel.
  - Numeric transitions become identity.

## 11. What changes in the design record

- **Principle 1, "the Mac app is the web client made native":** the navigation no longer mirrors the web's. The sidebar lists places, which the web never did. This goes in the "changed on purpose" table.
- **Section labels:** sentence case (§8).
- **Palette:** a new kind section with the measured values above.
- **Layouts:** the sidebar, the now strip and the toolbar.
- **A new Motion section.**
- **Controls:** the custom completion toggle.
- **Pictures:** `ShellMockupView` is redrawn to the new sidebar, and the PNGs are regenerated.

## Not in M9

- **The backend does not check that `area` matches the parent.** It accepts `area=study` with a project, and a project and a discipline together. Enforcing that would tighten validation, a contract change under invariant 8, so it is a follow-up issue with its own argument. The client derives the kind in one place (§1).
- **`#` type-ahead in capture** (for example `#lin` → Linear algebra) is an optional follow-up. `#` would count only when letters that match a place follow it, so "bug #123" stays a title.
- **⌘1–4 to switch screens in the main window.**
- **A configurable hotkey** (still ⌥⌘N, as M3.5 left it).
- **Tags.**

## Verification

Each slice:
1. **TDD:** the failing test first, and a regression test named after its issue for each bug.
2. **`apps/apple/gate.sh` green:**
   - swift-format and SwiftLint (with `raw_animation` from S2);
   - the layer check;
   - each package's tests at ≥ 90%;
   - xcodegen and xcodebuild.
   - S1 also runs `scripts/gate.sh` for the fixture.
3. **Its SMOKE.md section, run in the built app** against the running stack.
   - A screenshot of the window is compared with this spec.
   - Batch the in-app checks into one rebuild per slice: each rebuild prompts for Keychain access again.
4. **S1's smoke** launches over an existing M6 store, to prove the migration.

**By the end of M9:**
- ⌘N on Linear algebra's list, a title and ⏎ create a Study task under Linear algebra.
  - It appears in the list and the sidebar count goes up by one, animated.
  - `GET tasks/<id>` shows `area=study` and the discipline.
- Drawing a slot on Plan creates a task and a block in Study's colour. Offline it is queued, and it syncs when back online.
- With Reduce Motion on, nothing springs or bounces.
- Light and dark both hold.

## PRs

Each row is one issue, one branch and one PR to `develop`. `S1 →` means "after S1".

| | Title | After |
|---|---|---|
| S0 | `docs(M9): the kinds, places and capture design` (#252) | - |
| S1 | `feat(M9): a task knows its kind and parent` | S0 |
| S2 | `feat(M9): kind colours and motion tokens` | S0 |
| S3 | `refactor(M9): the main window moves into Features` | S0 |
| S4 | `feat(M9): one capture panel that knows where you are` | S1, S2, S3 |
| S5 | `feat(M9): re-file a task from the editor and the Inbox` | S4 |
| S6 | `feat(M9): a place's task list` | S1, S3 |
| S7 | `feat(M9): the sidebar shows your day and your places` | S4, S6 |
| S8 | `feat(M9): native toolbar and one screen header` | S7 |
| S9 | `feat(M9): calmer task rows` | S1, S2 |
| S10 | `feat(M9): calendar blocks wear their kind` | S1, S2 |
| S11 | `feat(M9): draw a slot to capture a task and its block` | S4, S10 |
| S12 | `feat(M9): motion` | S7, S11 |
| S13 | `docs(M9): the design record and smoke` | S12 |

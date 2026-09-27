# M9 The glass pass: design

**Status:** decided with the user 2026-09-27 (#281).
**Milestone:** M9, whose first spec is `2026-09-27-m9-kinds-and-places-design.md`. This one replaces that spec's visual parts where the two disagree, and says where.
**Design record:** `docs/design-system-apple.md`. S13 rewrites it to match.

## Why

The user ran M9's first merges (develop `6a52658`: capture with kinds, coloured blocks) and came back with this:

- **Things feel loose.** No two components look like they belong together. The Focus panel's **Complete** is a capsule; **Edit…**, **Reschedule** and **Remind me** next to it are rounded rectangles.
- **Density.** Plan's task cards are skinny and the app wastes a lot of space. Kanban cards do the same.
- **The new-task panel** takes only a name and a kind. It should take subtasks, notes and more.
- **Kanban drag** does nothing (#279).
- **Classes.** You can't add or configure a class from Plan, and classes added in Study don't appear on Plan (#280).
- **Plan** can't show only Work, only Study or only Life.
- **Projects:** clicking a project doesn't show its tasks.
- **Direction:** "something like Pixelmator Pro: the acrylic, Liquid Glass, transparent feeling I always talked about".

The problem underneath is that the app has no single component language. Pixelmator Pro gets its look from three rules, and this pass adopts all three:

1. The chrome is monochrome, and colour comes only from content.
2. Panels are glass that floats over a full-bleed canvas.
3. Every control belongs to one shape family.

## Decisions

The user chose these, in this order:

1. **Mono chrome, colour as marks.**
   - Everything you touch is ink or grey glass: buttons, chips, panels, selection.
   - Kinds survive only as small marks on data:
     - a 3-pt bar on blocks and rows;
     - a dot in the sidebar and on the chosen chip.
   - S10's tinted block fill and S4's coloured chip borders are reverted.
2. **Floating glass panels, solid content.**
   - The sidebar and a trailing **inspector** float as inset, rounded Liquid Glass panels.
   - The canvas (calendar, board or list) runs full-bleed underneath them.
   - Rows, cards and blocks stay solid, so text stays legible.
3. **The capture panel expands on demand.** Title and kind remain the quick path. ⌘E opens date, priority, estimate, notes and subtasks in place.

The rest is argued below and was approved with the design:
- one shape family;
- density;
- a kind filter on Plan;
- classes from Plan;
- project cards that open their lists.

## 1. The component pass (G1)

**Shape family.** One control shape: the **capsule**.

| Kind of control | Style | Example |
|---|---|---|
| Primary action, one per screen | `.primary`, an ink capsule, unchanged | Complete |
| Every other button and menu button | a new `.secondary`: a glass capsule the **same height** as the primary | Edit…, Reschedule ⌄, Remind me ⌄, Repeat ⌄ |
| Icon-only buttons | glass circles | ＋, the sidebar toggle |

- `ControlMetrics.height` in `Design/` is the one height every capsule shares.
- `ButtonStyleTests` pins that the primary and the secondary share it.
- `.glass` stays only where the system draws it for us, in toolbars.

**Radii**, already tokens (`Radius`), now used without exception:

| Size | Used for |
|---|---|
| 16 | panels, the capture panel |
| 12 | rows, cards |
| 8 | blocks, marks |

**Colour marks.**
- `KindChipsView` chips become grey glass capsules. The chosen chip gets an ink-tinted fill and a 6-pt dot in its kind colour.
- `CalendarItemView` blocks become quiet solid `surface`, with only the 3-pt bar in the mark colour. The faint tinted fill goes.
- `KindMarkView` (rows) is unchanged: it is already a mark.
- `KindTint` keeps its values and tests; only where they are used changes.

## 2. The shell: glass panels over a full-bleed canvas (G2, with S7 and S8)

**The sidebar** is macOS 26's floating glass sidebar, with S7's content:
- the now strip;
- Focus, Plan, Review, Inbox;
- Work, Study, Life;
- the footer.

It carries no background of its own, so the glass reads.

**The inspector** replaces the fixed 340-pt right-hand columns:
- Focus's task and timer panel (`FocusTaskPanelView`);
- Plan's detail panel (`PlanDetailPanelView`);
- the class inspector (§5).

Details:
- It uses SwiftUI's `.inspector(isPresented:)`, which macOS 26 draws as a floating glass panel.
- It is toggled from the toolbar (⌥⌘I) and by selection: selecting a task opens it.
- It is resizable, and its width is remembered in `@SceneStorage`.

**The canvas.**
- The detail content (the calendar grid, the board, the lists) extends under both panels with `backgroundExtensionEffect()`, so the glass has something to blur.
- The window ground stays `omakaseWindowBackground()`, the blurred desktop at `Translucency.window`.

**The toolbar** is S8's table (the first spec's §7), with each screen's controls in the window toolbar. G2 and S8 build it together.

## 3. Density (G3)

- **Rows** (`TaskRowView`, `PlanTaskRowView`, the triage and place rows) fill their column and use two lines:
  - the title, up to two lines;
  - a quiet meta line: kind mark, estimate, due date, and priority when it isn't Medium.
  - Padding is `Spacing.small` vertical and `Spacing.medium` horizontal.
- **Plan's task column** goes from 380 pt to a flexible 320–460 pt, with the calendar taking the rest.
- **Kanban cards** fill the column width with the same two-line layout. Columns share the width equally, with a minimum of 240 pt, and scroll horizontally below that.
- No fixed widths remain outside `Design/`: widths become `LayoutWidth` tokens.

## 4. Capture expands (G4)

**The panel** keeps title, kind chips and parent. ⏎ still saves at once.

**⌘E** (or a "More" button) expands the panel in place to:

| Field | What it does |
|---|---|
| Date | a day picker; sets the destination and replaces ⏎'s default |
| Priority | Low / Medium / High / Urgent |
| Estimate | minutes, as `15m`, `1h 30m` (`MinutesText`) |
| Notes | the task's `description`, as the editor calls it |
| Subtasks | one per line; ⏎ in the list adds a line, and ⌘⏎ saves the task |

- ⌘E again collapses it.
- Whether you like it open is remembered in `omakase.capture.expanded`.

**Writes.**
- `CaptureBody` gains `priority`, `estimated_minutes` and `description`, each left out when unset.
- Each subtask is queued as a `subtask.create` behind the task's `local-` id: `POST /api/v1/tasks/<id>/subtasks/`, with the path rewritten on accept (`OutboxRules.rewrite` already rewrites paths).
- The #274 fix re-points `SubtaskRecord.taskID`.
- **Backend** (invariant 9: a create the Mac outbox replays is idempotent): `POST tasks/<pk>/subtasks/` puts `IdempotentCreateMixin` first in its bases.
  - It gains `Idempotency-Key` support and changes no shape.
  - It gets a test that a replay with the same key returns the stored response.
  - CHANGELOG names it.

**Carried from S11's review:**
- **One tested helper.** The `.slot` sequence (task, then block, then subtasks) moves into one Store helper that the app and the tests both call.
- **Report failures.** A failure after the task was saved is reported, not swallowed by `try?`.
- **Don't lose a slot.** ⌘N while a slot draft is open keeps the slot.
- **Check the parent.** A kept parent is checked against the re-read directory.

## 5. Plan: filter by kind, classes from Plan (G5, G6)

**The kind filter (G5).**
- A toolbar control: three monochrome toggle chips (Work, Study, Life), each with its kind dot. All three are on by default.
- Turning a kind off hides it from Plan: its blocks, and its tasks in the task column. Class occurrences count as Study.
- The state is stored per window in `@SceneStorage("omakase.plan.kinds")`.
- A pure `PlanKindFilter` decides visibility and is tested.

**Classes from Plan (G6).**
- **＋ menu.** Plan's toolbar ＋ becomes a menu: New Task (⌘N) and **New Class…**.
  - New Class… opens the existing `StudyFormSheet`, seeded with the day and time Plan shows.
- **Class inspector.** Clicking a class occurrence opens it in the inspector:
  - its discipline and time;
  - its rotation (Week A/B, #126);
  - **Cancel this class** (#125);
  - **Edit schedule…** (the same sheet).
- **The Study screen** keeps semesters, disciplines and holidays, in G1's components. Its deeper redesign waits for the user's specifics.

## 6. Projects open their lists (G7)

A project card on the Projects screen opens that project's task list: `SidebarSelection.place(.project(id))` and S6's `PlaceTasksView`. Double-click opens it; a single click selects the card.

## 7. Bugs fixed in the same pass

Each is reproduced as a failing test first (AGENTS.md):

- **#276:** an expired token at launch leaves the window saying Offline.
- **#279:** dragging a card on Kanban does nothing.
- **#280:** a class added in Study doesn't appear on Plan.

## 8. What this changes in M9's first spec

- **§2 and §9:** S10's tinted block fill and S4's coloured chip borders become marks (§1 above).
- **§6:** the sidebar is S7's content inside a floating glass sidebar.
- **§7:** the toolbar table stands. G2 and S8 build it with the inspector.
- **§10, motion (S12):** it now also covers:
  - the inspector opening and closing (`layout`);
  - the capture panel expanding (`layout`);
  - the filter chips (`select`).
  Reduce Motion still removes all of it.
- **§11:** the design record also changes:
  - Principle 5 becomes "glass panels over a full-bleed canvas; solid content";
  - a new Components section records the shape family and the metrics.

## Not in this pass

- A redesign of the Study screen's structure. It waits for the user's specifics; G6 covers what they asked for.
- Tags.
- Custom kinds beyond Work, Study and Life.

## Verification

Each slice follows the first spec's rules: TDD, a green Apple gate, and a SMOKE.md section. At checkpoint B, with screenshots in dark and light:
- Focus's panel has one capsule height.
- Blocks are grey with coloured bars.
- The inspector floats over the calendar.
- ⌘E expands capture, and a task with three subtasks syncs.
- Turning Study off hides study blocks and classes.
- New Class… from Plan creates a class that appears on Plan.
- Double-clicking a project opens its list.
- Kanban drag works.

## PRs

| | Title | After |
|---|---|---|
| G0 | `docs(M9): the glass pass design` (#281) | - |
| G1 | `feat(M9): one shape family and colour as marks` | G0 |
| S7 | `feat(M9): the sidebar shows your day and your places` (#260), in the floating sidebar | G1, S6 |
| G2 | `feat(M9): a floating glass inspector over a full-bleed canvas` | S7 |
| S8 | `feat(M9): native toolbar and one screen header` (#261) | G2 |
| G3 | `feat(M9): denser rows and cards` | G1 |
| G4 | `feat(M9): the capture panel expands with ⌘E` (backend: idempotent subtask create) | G1 |
| G5 | `feat(M9): filter Plan by kind` | S8 |
| G6 | `feat(M9): add and configure classes from Plan` | G2, #280 |
| G7 | `feat(M9): a project card opens its tasks` | S6 |
| S5 | `feat(M9): re-file a task from the editor and the Inbox` (#258) | S6 |
| S12 | `feat(M9): motion` (#265) | G2, G4, G5 |
| S13 | `docs(M9): the design record and smoke` (#266) | all |

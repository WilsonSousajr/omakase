# Omakase Design System

Monochrome design inspired by wstech.tech, with Sunsama-style productivity layout. Supports light and dark themes via `next-themes`.

## Color Tokens

Defined as CSS custom properties in `frontend/src/app/globals.css`. Light values in `:root` (default), dark values in `.dark` class. `next-themes` toggles the `.dark` class on `<html>`.

### Backgrounds & Surfaces

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-bg` | `#ffffff` | `#0a0a0a` | Page background, sidebar |
| `--color-surface` | `#f5f5f5` | `#141414` | Cards, panels, kanban columns |
| `--color-surface-hover` | `#ebebeb` | `#1a1a1a` | Card hover, active toggle states |
| `--color-surface-elevated` | `#ffffff` | `#1e1e1e` | Modals, toasts, popovers |
| `--color-surface-active` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.08)` | Active nav items, selected states |

### Borders

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-border` | `#e5e5e5` | `#232323` | Card/section borders, dividers |
| `--color-border-hover` | `#d4d4d4` | `#2a2a2a` | Border hover states, drag-over |

### Inputs

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-input` | `#fafafa` | `#0e0e0e` | Input/textarea/select backgrounds |

### Text

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-text-primary` | `#0a0a0a` | `#ffffff` | Headings, titles, active text |
| `--color-text-secondary` | `#525252` | `#a3a3a3` | Body text, descriptions |
| `--color-text-muted` | `#737373` | `#737373` | Labels, hints, metadata |
| `--color-text-faint` | `#a3a3a3` | `#525252` | Disabled text, icons, timestamps |

### Buttons

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-button-primary` | `#171717` | `#e5e5e5` | Primary button background |
| `--color-button-primary-hover` | `#262626` | `#d4d4d4` | Primary button hover |
| `--color-button-primary-text` | `#ffffff` | `#0a0a0a` | Primary button text |

### Overlays

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `--color-hover-overlay` | `rgba(0,0,0,0.04)` | `rgba(255,255,255,0.05)` | Subtle hover feedback |
| `--color-overlay-medium` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.10)` | Medium emphasis backgrounds |
| `--color-ring-overlay` | `rgba(0,0,0,0.10)` | `rgba(255,255,255,0.10)` | Ring/border accents |

### Functional Accent Colors (priorities/tags only)

These are the ONLY non-monochrome colors in the app:

| Priority | Color | Usage |
|----------|-------|-------|
| Low | `#6b7280` | Badge bg, time block border |
| Medium | `#f59e0b` | Badge bg, time block border |
| High | `#f97316` | Badge bg, time block border |
| Urgent | `#ef4444` | Badge bg, time block border, error toasts |

Accent colors use opacity suffixes for backgrounds: `color + "20"` (badges), `color + "18"` (time blocks), `color + "40"` (borders).

## Typography

**Font:** [Outfit](https://fonts.google.com/specimen/Outfit) — geometric sans-serif, imported via Next.js Google Fonts.

### Type Scale

| Element | Size | Weight | Extra | Example |
|---------|------|--------|-------|---------|
| Section labels | `10px` | 600 (semibold) | `uppercase tracking-[0.15em]` | "TODO", "PRIORITY", time labels |
| Form labels | `10px` | 600 | `uppercase tracking-[0.15em]` | Input labels in modals |
| Badges/tags | `10px` | 500 | — | Priority badges, tag pills |
| Card titles | `14px` | 500 | — | Task names |
| Body text | `14px` | 400 | — | Descriptions, notes |
| Modal titles | `16px` | 600 | — | Form dialog headers |
| Pomodoro timer | `30px` | 300 (light) | `tabular-nums` | 25:00 display |

### Signature Element

The uppercase + wide tracking on section labels is the key wstech.tech aesthetic:
```
text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]
```

Applied to: kanban column headers, form labels, calendar time labels, pomodoro session labels.

## Component Patterns

### Card (universal building block)

```
rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)]
p-4 transition-all duration-300
hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]
```

Applied to: task cards, kanban cards, kanban columns, timer card, markdown editor.

### Primary Button

```
rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5
text-xs font-medium text-[var(--color-button-primary-text)]
transition-colors hover:bg-[var(--color-button-primary-hover)]
```

### Ghost/Secondary Button

```
rounded-xl px-3 py-1.5 text-xs
text-[var(--color-text-secondary)]
hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]
```

### Icon Button

```
rounded-lg p-2
text-[var(--color-text-faint)]
hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]
```

### Danger Button

```
rounded-lg p-1
text-[var(--color-text-faint)]
hover:bg-[#ef4444]/10 hover:text-[#ef4444]
```

### Input / Textarea / Select

```
rounded-xl border border-[var(--color-border)] bg-[var(--color-input)]
px-3.5 py-2.5 text-sm
text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)]
outline-none focus:border-[var(--color-text-secondary)]/40
```

### Modal

```
Overlay: bg-black/60 fixed inset-0 z-50
Content: rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl
Header: border-b border-[var(--color-border)] px-6 py-4
Body: p-6
```

### Badge / Tag

```
rounded-lg px-1.5 py-0.5 text-[10px]
style={{ backgroundColor: color + "20", color }}
```

### Project Badge

Same as tag badge but with a FolderOpen icon prefix. Appears in TaskCard metadata row alongside tags and scheduled date.

```
flex items-center gap-1 rounded-lg px-1.5 py-0.5 text-[10px]
style={{ backgroundColor: color + "20", color }}
Icon: FolderOpen h-2.5 w-2.5
```

### Project Card

Uses the standard card pattern with a color dot indicator, description preview, task count, and optional due date.

```
Color dot: h-3 w-3 rounded-full (inline style backgroundColor)
Task count: ListTodo icon + "N tasks" in text-[10px] text-[var(--color-text-muted)]
Due date: CalendarDays icon + formatted date
```

## Border Radius Scale

| Component | Radius | Tailwind |
|-----------|--------|----------|
| Cards, columns, modals | 16px | `rounded-2xl` |
| Inputs, buttons, toggles | 12px | `rounded-xl` |
| Badges, icon buttons | 8px | `rounded-lg` |
| Pill-shaped (special) | full | `rounded-full` |

## Spacing

| Area | Value | Tailwind |
|------|-------|----------|
| Page padding | 20px | `p-5` |
| Card padding | 16px | `p-4` |
| Card gap (lists) | 12px | `space-y-3` |
| Kanban column gap | 20px | `gap-5` |
| Modal body padding | 24px | `p-6` |

## Transitions

- Cards: `transition-all duration-300` (background + border on hover)
- Buttons: `transition-colors` (color change only)
- Sidebar collapse: `transition-all duration-200`
- SVG pomodoro ring: `transition: stroke-dashoffset 0.5s ease`

## Pomodoro Session Colors (Monochrome)

| Session | Text Class | Stroke Class | Intensity |
|---------|-----------|-------------|-----------|
| Focus | `text-[#e5e5e5]` | `stroke-[#e5e5e5]` | Bright |
| Short Break | `text-[#737373]` | `stroke-[#737373]` | Medium |
| Long Break | `text-[#a3a3a3]` | `stroke-[#a3a3a3]` | Light |

Session labels use the uppercase tracking signature for differentiation.

## Active / Selected States

| Context | Pattern |
|---------|---------|
| Sidebar nav | `bg-[var(--color-surface-active)] text-[var(--color-text-primary)]` |
| Kanban card | `border-[var(--color-ring-overlay)] ring-1 ring-[var(--color-ring-overlay)]` |
| Toggle active | `bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]` |
| Drop zone | `bg-[var(--color-hover-overlay)]` |
| Tab active | `border-b-2 border-[var(--color-text-primary)]` |

## Scrollbar

```css
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-thumb { background: var(--color-scrollbar); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--color-scrollbar-hover); }
```

## Error States

Toast uses elevated surface bg with red accent text:
```
rounded-2xl border border-[#ef4444]/20 bg-[var(--color-surface-elevated)]
text-[#ef4444] shadow-lg
```

### Sidebar Stats Panel

Bottom-anchored panel in sidebar (`mt-auto`), only visible when sidebar is expanded. Two sections: "Today" and "This Week".

```
Container: border-t border-[var(--color-border)] px-3 py-3
Section label: text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]
Stat row: flex items-center gap-2, icon h-3.5 w-3.5 text-[var(--color-text-faint)]
Stat text: text-xs text-[var(--color-text-secondary)]
Progress bar: h-1 rounded-full bg-[var(--color-surface)], fill bg-[var(--color-text-secondary)]
Weekly labels: text-[11px] text-[var(--color-text-faint)]
```

Icons: Clock (hours), BarChart3 (blocks), Flame (streak). Sections conditionally hidden when data is zero.

### Study Components

**SemesterCard:** Card with name, institution, discipline count, date range. Click-to-select with `ring-[var(--color-ring-overlay)]` active indicator.

**DisciplineCard:** Card with color dot, name, code, professor, block count, credits. Supports `onClick` for navigation to detail page.

**StudyBlockCard:** `React.memo` wrapped. Checkbox (priority-colored when complete), title, priority/type/discipline badges. Edit/delete on hover. Uses `onPointerDown` stopPropagation on buttons.

**DisciplineBadge:** BookOpen icon + colored badge (same pattern as ProjectBadge). Uses `color + "20"` for background alpha.

**TodayStudyBlocks:** Focus page panel below kanban. Shows scheduled study blocks for today with completion toggles and discipline badges. Conditionally rendered (hidden when empty).

**Calendar TimeBlock (Notion-style):** Left accent stripe (`w-1 rounded-l-xl`, priority/discipline color), white title text (`text-[var(--color-text-primary)]`), subtle border (`color + "25"`), ultra-light bg (`color + "12"`). `rounded-xl`, `transition-all duration-200`, `hover:shadow-lg hover:shadow-black/20`. `data-timeblock` attribute for click-to-create conflict avoidance.

```
Accent stripe: absolute left-0 top-0 bottom-0 w-1 rounded-l-xl, bg: color
Border: borderColor: color + "25"
Background: backgroundColor: color + "12"
Title: text-xs font-medium text-[var(--color-text-primary)]
Time: text-[10px] text-[var(--color-text-muted)]
Padding: pl-3.5 pr-3 py-1.5
```

**ClassBlockItem (calendar):** Read-only calendar block for virtual class occurrences. Dashed border, ultra-light bg (`color + "0d"`), BookOpen icon, discipline name, class type badge, time range, optional location with MapPin icon. Not draggable, not resizable — purely informational. `data-classblock` attribute. `rounded-xl`.

```
Dashed border: border border-dashed, borderColor: color + "50"
Ultra-light bg: backgroundColor: color + "0d"
Title: text-xs font-medium, color: color + "c0"
Type badge: text-[9px] font-semibold capitalize, bg: color + "18", color: color + "90"
Time + location: text-[10px], color: color + "70" / "60"
```

**CurrentTimeIndicator:** Red line (`bg-red-500 h-[2px]`) + dot (`w-2 h-2 rounded-full bg-red-500`) at current time position. Updates every 60s. Only renders when `isToday=true`. In week view, renders only in the today column.

**CreationOverlay:** Ghost preview for click-to-create. Translucent (`bg-white/10 border-white/20 rounded-xl`), shows start/end time labels. `transition-opacity duration-100`.

**Calendar Grid Lines:** Hour lines use `border-[var(--color-border)]/60`, half-hour lines use `border-[var(--color-border)]/20` — Notion-style visual hierarchy. Week view column borders: `/30`.

**Calendar Header:** Today button is a visible pill (`rounded-xl border border-[var(--color-border)]`). Date label `text-base font-medium`. View toggle is a segmented control (`overflow-hidden rounded-xl`).

**Week View Day Headers:** Two-line layout: day abbreviation + date number. Today's date gets a white circle (`rounded-full bg-white text-black w-6 h-6`). Today column has `bg-white/[0.02]` highlight.

**Click-to-Create:** Draw on empty calendar space → CreationOverlay appears → mouseup opens TaskForm with pre-filled scheduled_date. Uses `useClickToCreate` hook with 5px dead zone, 15-min snap, dnd-kit conflict avoidance via `disabled` prop. Only available in day view.

**ClassScheduleForm:** Modal form for adding/editing recurring class schedules on a discipline. Day-of-week select, time range inputs, class type select, location text input. Uses `modalOpen === "classschedule-form"`.

**Class Schedule List (discipline detail):** Inline management section below study blocks on `/study/[disciplineId]`. Each schedule row shows day, type badge, active status, time range, location. Edit (Pencil) and delete (Trash2) icons on hover.

```
Study form modals: "semester-form", "discipline-form", "studyblock-form", "classschedule-form"
Study page: /study — semesters grid + disciplines grouped by status
Discipline detail: /study/[disciplineId] — study blocks list + class schedule management
Sidebar: BookOpen icon nav item + semester selector dropdown
```

### Review Components

**Review Page:** 6-step wizard at `/review`. Step indicator: dot + line progress bar at top (`h-1.5 w-1.5 rounded-full`, connected by `h-px w-6` lines). Content area centered with `max-w-2xl`.

**ReviewSummary (Step 0):** Stats row with 3 cards (hours focused, blocks completed/total, completion %). Completed items with green Check icon, incomplete items with amber Circle icon and `border-amber-500/20`.

**ReviewRollover (Step 1):** Cards for each incomplete item with 4 action buttons (Tomorrow, Pick date, Backlog, Skip). Selected card dims with `opacity-60` and shows action label badge. "Apply & Continue" disabled until all items have decisions.

**ReviewScore (Step 2):** 5 rating buttons (1-5) with labels. Selected button gets `ring-1 ring-[var(--color-ring-overlay)] bg-[var(--color-overlay-medium)]`. Continue disabled until selection.

**ReviewWin (Step 3):** Textarea with placeholder. Optional — has both "Skip" (ghost link) and "Continue" (primary button).

**ReviewPreview (Step 4):** Read-only list of tomorrow's class occurrences (dashed border, discipline color dot), tasks, and study blocks.

**ReviewShutdown (Step 5):** Centered Moon icon, two states: pre-shutdown ("Shut Down" primary button) and post-shutdown ("Great work today. Time to rest." with "Close" ghost button → `/plan`).

**Review Tab Bar:** Today / History tabs above wizard content. Same pattern as MarkdownEditor tabs: `border-b-2 border-[var(--color-text-primary)]` for active, `text-[var(--color-text-muted)]` for inactive. `px-4 py-2 text-xs font-medium capitalize`.

**ReviewHistory:** Paginated list of past reviews (`space-y-3`). Empty state: centered muted text. "Load more" ghost button when more pages exist. Contained in `max-w-2xl` centered wrapper.

**ReviewHistoryCard:** `React.memo` wrapped. Compact view: date + year (signature label style), 5 rating dots (`h-1.5 w-1.5 rounded-full`), win excerpt (`line-clamp-1`), Moon icon when shutdown, ChevronDown (rotates 180 on expand). Card: `rounded-2xl border bg-surface hover:bg-surface-hover`. Expanded view: lazy-loaded summary stats in `rounded-xl bg-bg p-3` cards, completed items (green Check), incomplete items (amber Circle). Loading spinner while fetching.

```
Sidebar nav order: Plan → Focus → Review → Projects → Study
Sidebar bottom: User avatar section → SidebarStats (both inside mt-auto)
Settings link: user avatar section links to /settings, Settings gear icon from lucide-react
Review icon: CheckSquare from lucide-react
Settings icon: Settings (gear) from lucide-react
```

### Theme Toggle

Located in sidebar footer. Cycles through system → light → dark themes. Uses `next-themes` for localStorage persistence and system preference detection.

```
Icons: Monitor (system), Sun (light), Moon (dark)
Button: rounded-lg p-1.5 text-[var(--color-text-faint)] hover:bg-[var(--color-surface)]
Storage key: "omakase-theme"
```

Uses `hasMounted` gate to avoid SSR hydration mismatch (same pattern as AuthGuard).

### Locale Switcher

Located in sidebar footer alongside ThemeToggle. Toggles between EN and PT-BR. Uses Zustand `localeStore` with localStorage persistence.

```
Button: rounded-lg px-2 py-1 text-[10px] font-semibold uppercase tracking-[0.15em]
Active: bg-[var(--color-surface-active)] text-[var(--color-text-primary)]
Inactive: text-[var(--color-text-faint)] hover:text-[var(--color-text-secondary)]
Storage key: "omakase-locale"
```

## Internationalization (i18n)

Uses `next-intl` in client-only mode (no middleware, no URL routing). Locale is stored in Zustand and toggled via sidebar UI.

### Translation Key Conventions

Keys organized by domain namespace in `messages/{locale}.json`:

| Namespace | Contents |
|-----------|----------|
| `common` | Shared buttons (cancel, continue, save, delete, loading...) |
| `auth` | Login/register form labels |
| `sidebar` | Navigation items, workspace/semester selectors |
| `tasks` | Task form labels, placeholders, empty states |
| `constants` | Enum display values (priorities, areas, statuses, types, days) |
| `pomodoro` | Timer labels, session types |
| `kanban` | Column headers, drop zone text |
| `calendar` | View mode labels, date-related UI |
| `projects` | Project form labels, empty states |
| `study` | Semester/discipline/study block/class schedule form labels |
| `review` | All 6 wizard steps, history section |
| `stats` | Sidebar stats labels |
| `topbar` | Top bar actions |
| `errors` | Error messages |

### Usage Patterns

```tsx
// Single namespace
const t = useTranslations("tasks");
t("title")  // → "Title"

// Constants (enum labels)
const tc = useTranslations("constants");
tc(`priorities.${priority.value}`)  // → "High"

// Parameterized strings
t("tasks", { count: 5 })  // → "5 tasks"

// Date formatting (locale-aware)
const fmt = useFormatter();
fmt.dateTime(date, { month: "short", day: "numeric" })  // → "Mar 9" (en) / "9 de mar." (pt-BR)
```

### User Avatar

Initials-based avatar with user-selected background color. Uses `style={{ backgroundColor }}` (dynamic). White text, `rounded-full`, `font-semibold`.

| Size | Class | Usage |
|------|-------|-------|
| `sm` | `h-7 w-7 text-[10px]` | Collapsed sidebar |
| `md` | `h-8 w-8 text-xs` | Expanded sidebar |
| `lg` | `h-16 w-16 text-xl` | Settings page preview |

Initials logic: `first_name[0] + last_name[0]` → `first_name[0:2]` → `username[0:2]`. Component is `React.memo` wrapped.

### Sidebar User Section

Bottom-anchored section inside `mt-auto` block, above `SidebarStats`, with `border-t`. Links to `/settings`.

```
Expanded: UserAvatar(md) + username (text-xs, truncated) + Settings gear icon (h-3.5 w-3.5 text-faint)
Collapsed: UserAvatar(sm) only, centered
Container: hover:bg-[var(--color-surface)] transition-colors
```

### Settings Page

Full page at `/settings` with `max-w-2xl mx-auto`. Six card sections stacked vertically:

```
Profile card: UserAvatar(lg) preview + ColorSwatchPicker + readonly username + editable name/email fields + Save button
Pomodoro card: 2x2 grid of number inputs (work, short break, long break, sessions before long break) + Save button with Save icon
Daily Goals card: 2-column grid (work hours, study hours) with 0.5 step increments
General card: 2-column grid (week starts on select, timezone text input)
Password card: old/new/confirm password inputs + Change Password button
Logout card: red text ghost button ("Log out") with hover:bg-red-400/10
```

All sections use `rounded-2xl border bg-surface p-5`. Inputs follow standard input pattern. Labels use signature `text-[10px]` uppercase style. Preferences save button disabled when no changes. Success feedback via `emitToast`.

### Error Boundary

`ErrorBoundary` component wraps `<main>` content in root layout. On render error, shows centered message with "Try Again" button (primary button style). Uses class component (`getDerivedStateFromError`).

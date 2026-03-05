# Omakase Design System

Monochrome design inspired by wstech.tech, with Sunsama-style productivity layout. Dark-only theme.

## Color Tokens

Defined as CSS custom properties in `frontend/src/app/globals.css` under `:root`.

### Backgrounds & Surfaces

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-bg` | `#0a0a0a` | Page background, sidebar |
| `--color-surface` | `#141414` | Cards, panels, kanban columns |
| `--color-surface-hover` | `#1a1a1a` | Card hover, active toggle states |
| `--color-surface-elevated` | `#1e1e1e` | Modals, toasts, popovers |
| `--color-surface-active` | `rgba(255,255,255,0.08)` | Active nav items, selected states |

### Borders

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-border` | `#232323` | Card/section borders, dividers |
| `--color-border-hover` | `#2a2a2a` | Border hover states, drag-over |

### Inputs

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-input` | `#0e0e0e` | Input/textarea/select backgrounds |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-text-primary` | `#ffffff` | Headings, titles, active text |
| `--color-text-secondary` | `#a3a3a3` | Body text, descriptions |
| `--color-text-muted` | `#737373` | Labels, hints, metadata |
| `--color-text-faint` | `#525252` | Disabled text, icons, timestamps |

### Buttons

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-button-primary` | `#e5e5e5` | Primary button background |
| `--color-button-primary-hover` | `#d4d4d4` | Primary button hover |
| `--color-button-primary-text` | `#0a0a0a` | Primary button text |

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
hover:bg-white/5 hover:text-[var(--color-text-primary)]
```

### Icon Button

```
rounded-lg p-2
text-[var(--color-text-faint)]
hover:bg-white/5 hover:text-[var(--color-text-secondary)]
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
| Kanban card | `border-white/20 ring-1 ring-white/10` |
| Toggle active | `bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]` |
| Drop zone | `bg-white/5` |
| Tab active | `border-b-2 border-[var(--color-text-primary)]` |

## Scrollbar

```css
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-thumb { background: #232323; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #2a2a2a; }
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

**SemesterCard:** Card with name, institution, discipline count, date range. Click-to-select with `ring-white/20` active indicator.

**DisciplineCard:** Card with color dot, name, code, professor, block count, credits. Supports `onClick` for navigation to detail page.

**StudyBlockCard:** `React.memo` wrapped. Checkbox (priority-colored when complete), title, priority/type/discipline badges. Edit/delete on hover. Uses `onPointerDown` stopPropagation on buttons.

**DisciplineBadge:** BookOpen icon + colored badge (same pattern as ProjectBadge). Uses `color + "20"` for background alpha.

**TodayStudyBlocks:** Focus page panel below kanban. Shows scheduled study blocks for today with completion toggles and discipline badges. Conditionally rendered (hidden when empty).

**Calendar TimeBlock (study):** Uses discipline color instead of priority color, BookOpen icon prefix. Same resize/drag behavior as task time blocks.

**ClassBlockItem (calendar):** Read-only calendar block for virtual class occurrences. Dashed border, ultra-light bg (`color + "0d"`), BookOpen icon, discipline name, class type badge, time range, optional location with MapPin icon. Not draggable, not resizable — purely informational.

```
Dashed border: border border-dashed, borderColor: color + "50"
Ultra-light bg: backgroundColor: color + "0d"
Title: text-xs font-medium, color: color + "c0"
Type badge: text-[9px] font-semibold capitalize, bg: color + "18", color: color + "90"
Time + location: text-[10px], color: color + "70" / "60"
```

**ClassScheduleForm:** Modal form for adding/editing recurring class schedules on a discipline. Day-of-week select, time range inputs, class type select, location text input. Uses `modalOpen === "classschedule-form"`.

**Class Schedule List (discipline detail):** Inline management section below study blocks on `/study/[disciplineId]`. Each schedule row shows day, type badge, active status, time range, location. Edit (Pencil) and delete (Trash2) icons on hover.

```
Study form modals: "semester-form", "discipline-form", "studyblock-form", "classschedule-form"
Study page: /study — semesters grid + disciplines grouped by status
Discipline detail: /study/[disciplineId] — study blocks list + class schedule management
Sidebar: BookOpen icon nav item + semester selector dropdown
```

### Error Boundary

`ErrorBoundary` component wraps `<main>` content in root layout. On render error, shows centered message with "Try Again" button (primary button style). Uses class component (`getDerivedStateFromError`).

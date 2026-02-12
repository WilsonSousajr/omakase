# Design System Refactor: Monochrome Sunsama — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the entire Omakase frontend from zinc/indigo Tailwind palette to wstech.tech-inspired monochrome design system with Outfit font, rounded-2xl cards, and functional-only accent colors.

**Architecture:** Define CSS custom properties in globals.css, swap all hardcoded zinc-*/indigo-* Tailwind classes with CSS variable references across 21 component files. Font change from Inter to Outfit in layout.tsx. No structural/logic changes — purely visual.

**Tech Stack:** Tailwind CSS 4, Next.js 15 (App Router), CSS custom properties, Google Fonts (Outfit)

**Design doc:** `docs/plans/2026-02-12-design-system-refactor-design.md`

---

### Task 1: Define CSS Custom Properties & Swap Font

**Files:**
- Modify: `frontend/src/app/globals.css`
- Modify: `frontend/src/app/layout.tsx`

**Step 1: Add CSS custom properties to globals.css**

Add the design token variables under `:root` and update the scrollbar colors in `globals.css`:

```css
@import "tailwindcss";

:root {
  --color-bg: #0a0a0a;
  --color-surface: #141414;
  --color-surface-hover: #1a1a1a;
  --color-surface-elevated: #1e1e1e;
  --color-border: #232323;
  --color-border-hover: #2a2a2a;
  --color-input: #0e0e0e;
  --color-text-primary: #ffffff;
  --color-text-secondary: #a3a3a3;
  --color-text-muted: #737373;
  --color-text-faint: #525252;
}
```

Update scrollbar thumb colors:
- `background: #3f3f46` → `background: #232323`
- `background: #52525b` → `background: #2a2a2a`

**Step 2: Swap Inter → Outfit in layout.tsx**

Replace the Inter import with Outfit:
```tsx
import { Outfit } from "next/font/google";

const outfit = Outfit({ subsets: ["latin"] });
```

Update the `<body>` className:
- `bg-zinc-950 text-zinc-100` → `text-[var(--color-text-primary)]` with `style={{ backgroundColor: 'var(--color-bg)' }}`

Or simpler approach: use Tailwind's arbitrary value syntax:
- `bg-[#0a0a0a] text-[var(--color-text-primary)]`

Update the font class reference from `inter.className` to `outfit.className`.

**Step 3: Verify the app loads**

Run: `docker compose up` and open http://localhost:3000
Expected: App loads with Outfit font and darker #0a0a0a background. Components still use old zinc colors (that's fine — we'll migrate them next).

**Step 4: Commit**

```bash
git add frontend/src/app/globals.css frontend/src/app/layout.tsx
git commit -m "feat: add monochrome design tokens and swap to Outfit font"
```

---

### Task 2: Sidebar & TopBar (App Shell)

**Files:**
- Modify: `frontend/src/components/Sidebar.tsx`
- Modify: `frontend/src/components/TopBar.tsx`

**Step 1: Update Sidebar.tsx**

Color replacements:
- `border-zinc-800` → `border-[var(--color-border)]`
- `bg-zinc-950` → `bg-[var(--color-bg)]`
- `text-indigo-400` (logo) → `text-[var(--color-text-secondary)]`
- `text-zinc-500` → `text-[var(--color-text-faint)]`
- `hover:bg-zinc-800` → `hover:bg-[var(--color-surface)]`
- `hover:text-zinc-300` → `hover:text-[var(--color-text-secondary)]`

Active nav state:
- `bg-indigo-500/15 text-indigo-400` → `bg-white/8 text-[var(--color-text-primary)]`

Inactive nav:
- `text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200` → `text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]`

Border radius:
- `rounded` (collapse button) → `rounded-lg`
- `rounded-md` (nav items) → `rounded-xl`

Transition:
- Keep `transition-all duration-200` on the sidebar container (collapse animation)

**Step 2: Update TopBar.tsx**

Color replacements:
- `border-b border-zinc-800` → remove border entirely (use negative space)
- `bg-zinc-950` → `bg-[var(--color-bg)]`
- `text-zinc-400` → `text-[var(--color-text-secondary)]`

"New Task" button:
- `rounded-md bg-indigo-600 px-3 py-1.5 text-xs text-white transition-colors hover:bg-indigo-500` →
  `rounded-xl bg-[#e5e5e5] px-3 py-1.5 text-xs font-medium text-[#0a0a0a] transition-colors hover:bg-[#d4d4d4]`

**Step 3: Verify sidebar + topbar visually**

Open http://localhost:3000. Check:
- Sidebar background matches page bg (#0a0a0a)
- Nav items have rounded-xl corners
- Active nav uses white/8 bg instead of indigo
- TopBar has no bottom border
- "New Task" button is light gray on black

**Step 4: Commit**

```bash
git add frontend/src/components/Sidebar.tsx frontend/src/components/TopBar.tsx
git commit -m "feat: apply monochrome design to sidebar and topbar"
```

---

### Task 3: TaskCard & TaskList

**Files:**
- Modify: `frontend/src/components/tasks/TaskCard.tsx`
- Modify: `frontend/src/components/tasks/TaskList.tsx`

**Step 1: Update TaskCard.tsx**

Card container:
- `rounded-lg border border-zinc-800 bg-zinc-900 p-3 transition-colors hover:border-zinc-700` →
  `rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-all duration-300 hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]`

Checkbox/grip icon:
- `text-zinc-600` → `text-[var(--color-text-faint)]`

Title:
- `text-sm text-zinc-200` → `text-sm text-[var(--color-text-primary)]`

Priority badge — keep existing inline style pattern (functional accent colors unchanged).
- Border radius on badge: `rounded px-1.5 py-0.5` → `rounded-lg px-1.5 py-0.5`

Metadata text:
- `text-xs text-zinc-500` → `text-xs text-[var(--color-text-muted)]`

Tag badges:
- `rounded px-1.5 py-0.5` → `rounded-lg px-1.5 py-0.5`
- Keep inline color styles (functional accents)

Timestamp:
- `text-[10px] text-zinc-500` → `text-[10px] text-[var(--color-text-muted)]`

Action buttons:
- Edit: `rounded p-1 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300` →
  `rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]`
- Delete: `rounded p-1 text-zinc-500 hover:bg-red-900/50 hover:text-red-400` →
  `rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[#ef4444]/10 hover:text-[#ef4444]`

Section labels (if any column headers like "TODO", "DONE" appear here):
- Apply uppercase tracking: `text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]`

**Step 2: Update TaskList.tsx**

Header area:
- `border-b border-zinc-800 p-3` → `border-b border-[var(--color-border)] p-4`

List spacing:
- `space-y-2 p-3` → `space-y-3 p-4`

Loading skeleton:
- `rounded-lg border border-zinc-800 bg-zinc-900` → `rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)]`

Empty state:
- `text-zinc-500` → `text-[var(--color-text-muted)]`

**Step 3: Verify task list visually**

Navigate to /plan. Check:
- Task cards have rounded-2xl (16px) corners
- Cards use #141414 background with #232323 borders
- Hover transitions are smooth 300ms
- Priority/tag badges still show correct colors
- More padding inside cards (p-4 vs p-3)

**Step 4: Commit**

```bash
git add frontend/src/components/tasks/TaskCard.tsx frontend/src/components/tasks/TaskList.tsx
git commit -m "feat: apply monochrome design to task cards and list"
```

---

### Task 4: TaskForm Modal & TaskFilters

**Files:**
- Modify: `frontend/src/components/tasks/TaskForm.tsx`
- Modify: `frontend/src/components/tasks/TaskFilters.tsx`

**Step 1: Update TaskForm.tsx**

Modal container:
- `rounded-xl border border-zinc-800 bg-zinc-900 shadow-2xl` →
  `rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl`

Modal header:
- `border-b border-zinc-800 px-5 py-3` → `border-b border-[var(--color-border)] px-6 py-4`
- Title: `text-sm text-zinc-200` → `text-base font-semibold text-[var(--color-text-primary)]`

Close button:
- `rounded p-1 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300` →
  `rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]`

Form body:
- `space-y-4 p-5` → `space-y-4 p-6`

All input fields (title, description, selects, date, time inputs):
- `rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 focus:border-indigo-500` →
  `rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[#a3a3a3]/40`

All form labels:
- `text-xs text-zinc-500` →
  `text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]`

Tag selection pills:
- Keep inline color styles for selected/unselected states
- `rounded-full px-2.5 py-1 text-xs` → `rounded-lg px-2.5 py-1 text-xs`

Cancel button:
- `rounded-md px-3 py-1.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200` →
  `rounded-xl px-3 py-1.5 text-xs text-[var(--color-text-secondary)] hover:bg-white/5 hover:text-[var(--color-text-primary)]`

Save button:
- `rounded-md bg-indigo-600 px-4 py-1.5 text-xs text-white transition-colors hover:bg-indigo-500` →
  `rounded-xl bg-[#e5e5e5] px-4 py-1.5 text-xs font-medium text-[#0a0a0a] transition-colors hover:bg-[#d4d4d4]`

**Step 2: Update TaskFilters.tsx**

Search icon:
- `text-zinc-500` → `text-[var(--color-text-faint)]`

Search input:
- `rounded-md border border-zinc-800 bg-zinc-900 py-1.5 pl-8 pr-3 text-xs text-zinc-200 placeholder-zinc-500 focus:border-indigo-500` →
  `rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] py-1.5 pl-8 pr-3 text-xs text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[#a3a3a3]/40`

Priority filter select:
- `rounded-md border border-zinc-800 bg-zinc-900 px-2 py-1.5 text-xs text-zinc-300 focus:border-indigo-500` →
  `rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-1.5 text-xs text-[var(--color-text-secondary)] outline-none focus:border-[#a3a3a3]/40`

**Step 3: Verify modal and filters**

Click "New Task" button. Check:
- Modal has rounded-2xl corners, elevated background (#1e1e1e)
- Form labels are uppercase with wide tracking
- Inputs have rounded-xl corners, #0e0e0e background
- Focus state shows gray border, not indigo
- Save button is light gray, Cancel is ghost

Close modal. Check:
- Search input and priority filter match new design

**Step 4: Commit**

```bash
git add frontend/src/components/tasks/TaskForm.tsx frontend/src/components/tasks/TaskFilters.tsx
git commit -m "feat: apply monochrome design to task form and filters"
```

---

### Task 5: Calendar Components

**Files:**
- Modify: `frontend/src/components/calendar/CalendarHeader.tsx`
- Modify: `frontend/src/components/calendar/CalendarDayView.tsx`
- Modify: `frontend/src/components/calendar/CalendarWeekView.tsx`
- Modify: `frontend/src/components/calendar/TimeBlockItem.tsx`

**Step 1: Update CalendarHeader.tsx**

Container:
- `border-b border-zinc-800 px-4 py-2` → `border-b border-[var(--color-border)] px-5 py-3`

Nav buttons:
- `rounded p-1 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200` →
  `rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]`

"Today" button:
- `rounded px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200` →
  `rounded-lg px-2 py-0.5 text-xs text-[var(--color-text-muted)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]`

Date heading:
- `text-sm text-zinc-200` → `text-sm text-[var(--color-text-primary)]`

Day/Week toggle:
- Container: `rounded-md border border-zinc-800` → `rounded-xl border border-[var(--color-border)]`
- Active: `bg-zinc-800 text-zinc-200` → `bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]`
- Inactive: `text-zinc-500 hover:text-zinc-300` → `text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]`

**Step 2: Update CalendarDayView.tsx**

Grid borders:
- `border-b border-zinc-800/50` → `border-b border-[var(--color-border)]/50`
- `border-t border-zinc-800` → `border-t border-[var(--color-border)]`

Drop zone highlight:
- `bg-indigo-500/10` → `bg-white/5`

Time labels:
- `text-[10px] text-zinc-500` → `text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]`

**Step 3: Update CalendarWeekView.tsx**

Grid borders:
- `border-b border-zinc-800/30` → `border-b border-[var(--color-border)]/30`
- `border-t border-zinc-800/50` → `border-t border-[var(--color-border)]/50`
- `border-l border-zinc-800/50` → `border-l border-[var(--color-border)]/50`

Drop zone:
- `bg-indigo-500/10` → `bg-white/5`

Time labels:
- `text-[9px] text-zinc-500` → `text-[9px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]`

Week header:
- `border-b border-zinc-800 bg-zinc-950` → `border-b border-[var(--color-border)] bg-[var(--color-bg)]`

Today indicator:
- `text-indigo-400` → `text-[var(--color-text-primary)]`
- Non-today: `text-zinc-400` → `text-[var(--color-text-muted)]`

**Step 4: Update TimeBlockItem.tsx**

Block container:
- `rounded border px-2 py-1` → `rounded-lg border px-2 py-1`
- Keep dynamic inline color styles (priority-driven)

Priority badge inside time blocks:
- `rounded px-1 py-0.5` → `rounded-lg px-1 py-0.5`

Delete button and resize handle — keep opacity transitions, update hover if needed.

**Step 5: Verify calendar**

Navigate to /plan. Check:
- Calendar header has no indigo colors
- Day/Week toggle uses monochrome states
- Time labels use uppercase tracking style
- Dropping tasks highlights with white/5 not indigo
- Time blocks still show priority colors correctly

**Step 6: Commit**

```bash
git add frontend/src/components/calendar/CalendarHeader.tsx frontend/src/components/calendar/CalendarDayView.tsx frontend/src/components/calendar/CalendarWeekView.tsx frontend/src/components/calendar/TimeBlockItem.tsx
git commit -m "feat: apply monochrome design to calendar components"
```

---

### Task 6: Kanban Components

**Files:**
- Modify: `frontend/src/components/kanban/KanbanBoard.tsx`
- Modify: `frontend/src/components/kanban/KanbanColumn.tsx`
- Modify: `frontend/src/components/kanban/KanbanCard.tsx`

**Step 1: Update KanbanBoard.tsx**

Layout:
- `gap-4 p-4` → `gap-5 p-5`

Column wrapper (if board wraps columns):
- `rounded-xl border border-zinc-800 bg-zinc-950/50` → `rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)]/50`

**Step 2: Update KanbanColumn.tsx**

Column container:
- `rounded-xl border border-zinc-800 bg-zinc-950/50 transition-colors` →
  `rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)]/50 transition-all duration-300`

Drag-over state:
- `border-indigo-500/30 bg-indigo-500/5` → `border-[var(--color-border-hover)] bg-white/5`

Header:
- `border-b border-zinc-800 px-4 py-3` → `border-b border-[var(--color-border)] px-4 py-3`

Column title:
- `text-sm text-zinc-300` → `text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]`

Count badge:
- `rounded-full bg-zinc-800 px-2 py-0.5 text-[10px] text-zinc-400` →
  `rounded-lg bg-[var(--color-surface)] px-2 py-0.5 text-[10px] text-[var(--color-text-muted)]`

Content area:
- `space-y-2 p-3` → `space-y-3 p-4`

Empty state:
- `text-xs text-zinc-600` → `text-xs text-[var(--color-text-faint)]`

**Step 3: Update KanbanCard.tsx**

Card:
- `rounded-lg border bg-zinc-900 p-3 transition-colors` →
  `rounded-2xl border bg-[var(--color-surface)] p-4 transition-all duration-300`

Active/selected state:
- `border-indigo-500/50 ring-1 ring-indigo-500/20` → `border-white/20 ring-1 ring-white/10`

Default state:
- `border-zinc-800 hover:border-zinc-700` → `border-[var(--color-border)] hover:border-[var(--color-border-hover)]`

Checkbox:
- `text-zinc-600 hover:text-zinc-400` → `text-[var(--color-text-faint)] hover:text-[var(--color-text-muted)]`

Title:
- `text-sm text-zinc-200` → `text-sm text-[var(--color-text-primary)]`

Tags/badges:
- `rounded px-1.5 py-0.5` → `rounded-lg px-1.5 py-0.5`
- Keep inline color styles

Priority badge:
- Same as tags

**Step 4: Verify kanban**

Navigate to /focus. Check:
- Kanban columns have rounded-2xl corners
- Column titles are uppercase with tracking
- Cards match new card design (rounded-2xl, #141414 bg)
- Active card has white ring, not indigo
- Drag-over uses white/5 not indigo

**Step 5: Commit**

```bash
git add frontend/src/components/kanban/KanbanBoard.tsx frontend/src/components/kanban/KanbanColumn.tsx frontend/src/components/kanban/KanbanCard.tsx
git commit -m "feat: apply monochrome design to kanban components"
```

---

### Task 7: Focus Mode Components (ActiveTaskPanel, PomodoroTimer, MarkdownEditor)

**Files:**
- Modify: `frontend/src/components/focus/ActiveTaskPanel.tsx`
- Modify: `frontend/src/components/focus/PomodoroTimer.tsx`
- Modify: `frontend/src/components/focus/MarkdownEditor.tsx`

**Step 1: Update ActiveTaskPanel.tsx**

Layout:
- `gap-4 p-4` → `gap-5 p-5`

Section border:
- `border-t border-zinc-800 pt-4` → `border-t border-[var(--color-border)] pt-4`

Text colors:
- `text-sm text-zinc-200` → `text-sm text-[var(--color-text-primary)]`
- `text-xs text-zinc-500` → `text-xs text-[var(--color-text-muted)]`
- `text-xs text-zinc-400` → `text-xs text-[var(--color-text-secondary)]`

Empty state:
- `text-zinc-600` → `text-[var(--color-text-faint)]`

**Step 2: Update PomodoroTimer.tsx**

Timer card:
- `rounded-lg border border-zinc-800` → `rounded-2xl border border-[var(--color-border)]`

Session tabs:
- Active: `bg-zinc-800 text-zinc-200` → `bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]`
- Inactive: `text-zinc-500 hover:text-zinc-300` → `text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]`

SVG ring stroke colors (monochrome):
- `stroke-indigo-500` (focus) → `stroke-[#e5e5e5]`

Session label colors:
- `text-indigo-400` (focus) → `text-[#e5e5e5]`
- `text-emerald-400` (short break) → `text-[#737373]`
- `text-amber-400` (long break) → `text-[#a3a3a3]`

Session label text style:
- `text-[10px] text-zinc-500` → `text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]`

Control buttons:
- Skip: `rounded-full p-2 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300` →
  `rounded-full p-2 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]`

Start/Stop button:
- Inactive: `bg-zinc-800 text-zinc-300 hover:bg-zinc-700` → `bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]`
- Active/start: `bg-indigo-600 text-white hover:bg-indigo-500` → `bg-[#e5e5e5] text-[#0a0a0a] hover:bg-[#d4d4d4]`

Session count:
- `text-xs text-zinc-500` → `text-xs text-[var(--color-text-muted)]`

**Step 3: Update MarkdownEditor.tsx**

Container:
- `rounded-lg border border-zinc-800` → `rounded-2xl border border-[var(--color-border)]`

Tab bar:
- `border-b border-zinc-800` → `border-b border-[var(--color-border)]`

Active tab:
- `border-b-2 border-indigo-500 text-zinc-200` → `border-b-2 border-[var(--color-text-primary)] text-[var(--color-text-primary)]`

Inactive tab:
- `text-zinc-500 hover:text-zinc-300` → `text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]`

Textarea:
- `text-sm text-zinc-300 placeholder-zinc-600` → `text-sm text-[var(--color-text-secondary)] placeholder-[var(--color-text-faint)]`

Prose styles (markdown preview):
- `prose-headings:text-zinc-200` → `prose-headings:text-[var(--color-text-primary)]`
- `prose-p:text-zinc-400` → `prose-p:text-[var(--color-text-secondary)]`
- `prose-a:text-indigo-400` → `prose-a:text-[var(--color-text-primary)] prose-a:underline`
- `prose-strong:text-zinc-200` → `prose-strong:text-[var(--color-text-primary)]`
- `prose-code:text-indigo-300` → `prose-code:text-[var(--color-text-secondary)]`
- `prose-pre:bg-zinc-900` → `prose-pre:bg-[var(--color-surface)]`

Empty state:
- `text-zinc-600` → `text-[var(--color-text-faint)]`

**Step 4: Verify focus mode**

Navigate to /focus. Check:
- Pomodoro timer uses monochrome ring colors
- Session tabs are monochrome
- Start button is light gray, not indigo
- Markdown editor tabs use white underline, not indigo
- Prose preview has no indigo links/code colors
- Active task panel text hierarchy is clear

**Step 5: Commit**

```bash
git add frontend/src/components/focus/ActiveTaskPanel.tsx frontend/src/components/focus/PomodoroTimer.tsx frontend/src/components/focus/MarkdownEditor.tsx
git commit -m "feat: apply monochrome design to focus mode components"
```

---

### Task 8: Toast, Page Layouts & Final Polish

**Files:**
- Modify: `frontend/src/components/Toast.tsx`
- Modify: `frontend/src/app/plan/page.tsx`
- Modify: `frontend/src/app/focus/page.tsx`

**Step 1: Update Toast.tsx**

Error toast:
- `rounded-lg border border-red-900/50 bg-red-950/90 px-4 py-3 text-sm text-red-300 shadow-lg` →
  `rounded-2xl border border-[#ef4444]/20 bg-[var(--color-surface-elevated)] px-4 py-3 text-sm text-[#ef4444] shadow-lg`

Close button:
- `rounded p-0.5 hover:bg-red-900/50` → `rounded-lg p-0.5 hover:bg-[#ef4444]/10`

**Step 2: Update plan/page.tsx**

Panel border:
- `border-r border-zinc-800` → `border-r border-[var(--color-border)]`

**Step 3: Update focus/page.tsx**

Panel border:
- `border-r border-zinc-800` → `border-r border-[var(--color-border)]`

**Step 4: Full visual review**

Navigate through all pages and check:
- /plan: task list + calendar look cohesive
- /focus: kanban + pomodoro + markdown editor look cohesive
- Create a task: modal looks correct
- Drag a task: drag states use monochrome highlights
- Resize a time block: still works correctly
- Pomodoro: start/stop/skip all look right
- Toast: trigger an error and verify it matches

**Step 5: Commit**

```bash
git add frontend/src/components/Toast.tsx frontend/src/app/plan/page.tsx frontend/src/app/focus/page.tsx
git commit -m "feat: apply monochrome design to toast and page layouts"
```

---

### Task 9: Update Design System Documentation

**Files:**
- Create: `docs/design-system.md`
- Modify: `CLAUDE.md` (if needed)

**Step 1: Write docs/design-system.md**

Document the complete design system with:
- Color tokens (table with CSS variable name, hex, usage)
- Typography (Outfit, sizes, weights, the uppercase tracking pattern)
- Component patterns (card, button, input, badge specs)
- Border radius scale
- Spacing scale
- Transition patterns
- Functional accent color rules
- Active/selected state patterns

**Step 2: Update CLAUDE.md if any patterns changed**

Review if any Key Patterns or component behavior descriptions need updating.

**Step 3: Commit**

```bash
git add docs/design-system.md CLAUDE.md
git commit -m "docs: add design system documentation for monochrome refactor"
```

---

### Task 10: Delete Plan File & Final Commit

**Files:**
- Delete: `docs/plans/2026-02-12-design-system-refactor-design.md`
- Delete: `docs/plans/2026-02-12-design-system-refactor.md`

**Step 1: Remove completed plan files**

Per workflow rules, delete plan files after implementation is complete.

**Step 2: Commit**

```bash
git rm docs/plans/2026-02-12-design-system-refactor-design.md docs/plans/2026-02-12-design-system-refactor.md
git commit -m "chore: remove completed design system refactor plan files"
```

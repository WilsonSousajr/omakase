# Design System Refactor: Monochrome Sunsama

**Date:** 2026-02-12
**Status:** Approved
**Direction:** Sunsama layout/UX + wstech.tech monochrome polish
**Theme:** Dark only
**Scope:** Full app redesign (sidebar, topbar, plan page, focus page, modals, pomodoro)

## References

- **wstech.tech** — Monochrome bento card system, Outfit font, uppercase tracking labels
- **focusbrew.vercel.app/app** — Dark productivity app component patterns (Nunito/Roboto Slab/Satoshi)
- **Sunsama** — 3-panel layout, kanban, timeboxing UX, minimalist planner

## Color System

Replacing zinc-* Tailwind palette with custom CSS variables:

| Token | Hex | Usage | Replaces |
|-------|-----|-------|----------|
| `--color-bg` | `#0a0a0a` | Page background | `zinc-950` |
| `--color-surface` | `#141414` | Cards, panels, columns | `zinc-900` |
| `--color-surface-hover` | `#1a1a1a` | Hover states on cards | zinc-800 hover |
| `--color-surface-elevated` | `#1e1e1e` | Modals, dropdowns, popovers | new |
| `--color-border` | `#232323` | Card/section borders | `zinc-800` |
| `--color-border-hover` | `#2a2a2a` | Border hover states | `zinc-700` |
| `--color-input` | `#0e0e0e` | Input field backgrounds | `zinc-950` on inputs |
| `--color-text-primary` | `#ffffff` | Headings, key text | `zinc-100` |
| `--color-text-secondary` | `#a3a3a3` | Body text, descriptions | `zinc-400` |
| `--color-text-muted` | `#737373` | Labels, hints | `zinc-500` |
| `--color-text-faint` | `#525252` | Least important text | `zinc-600` |

### Functional Accent Colors (unchanged — priorities/tags only)

| Priority | Color |
|----------|-------|
| Low | `#6b7280` (gray) |
| Medium | `#f59e0b` (amber) |
| High | `#f97316` (orange) |
| Urgent | `#ef4444` (red) |

### Active/Interactive States (replacing indigo)

| Element | New Style | Old Style |
|---------|-----------|-----------|
| Active nav item | `bg-white/8 text-[#e5e5e5]` | `bg-indigo-500/15 text-indigo-400` |
| Active kanban card | `border-white/20 ring-1 ring-white/10` | `border-indigo-500/50 ring-indigo-500/20` |
| Primary button | `bg-[#e5e5e5] text-[#0a0a0a]` | `bg-indigo-600 text-white` |
| Primary button hover | `bg-[#d4d4d4]` | `bg-indigo-500` |
| Focus ring (inputs) | `border-[#a3a3a3]/40` | `border-indigo-500` |
| Drop zone highlight | `bg-white/5` | `bg-indigo-500/10` |

## Typography

**Font:** Outfit (Google Fonts, geometric sans-serif) — replaces Inter

| Element | Size | Weight | Tracking | Style |
|---------|------|--------|----------|-------|
| Section labels | `10px` | `600` | `0.15em` | `uppercase` (signature) |
| Form labels | `10px` | `600` | `0.15em` | `uppercase` |
| Card titles | `14px` | `500` | default | Normal case |
| Body text | `14px` | `400` | default | Normal case |
| Modal titles | `16px` | `600` | default | Normal case |
| Page heading | `14px` | `400` | default | `text-secondary` |
| Pomodoro timer | `30px` | `300` | default | `tabular-nums` |
| Badges/tags | `10px` | `500` | default | Normal case |

## Component Patterns

### Card (universal building block)

```
background: var(--color-surface)
border: 1px solid var(--color-border)
border-radius: 16px (rounded-2xl)
padding: 16px (p-4)
transition: all 300ms

:hover →
  background: var(--color-surface-hover)
  border-color: var(--color-border-hover)
```

### Buttons

| Type | Style |
|------|-------|
| Primary | `bg-[#e5e5e5] text-[#0a0a0a] rounded-xl px-4 py-2 text-sm font-medium` → hover `bg-[#d4d4d4]` |
| Secondary/Ghost | `text-[#a3a3a3] hover:bg-white/5 hover:text-[#e5e5e5] rounded-xl px-3 py-1.5` |
| Icon button | `text-[#525252] hover:bg-white/5 hover:text-[#a3a3a3] rounded-lg p-2` |
| Danger | `text-[#ef4444] hover:bg-[#ef4444]/10 rounded-xl` |

### Inputs

```
background: var(--color-input)
border: 1px solid var(--color-border)
border-radius: 12px (rounded-xl)
padding: 10px 14px
color: var(--color-text-primary)
placeholder: var(--color-text-muted)

:focus → border-color: rgba(163, 163, 163, 0.4)
```

### Border Radius Scale

| Component | Old | New |
|-----------|-----|-----|
| Cards, columns, panels | `rounded-lg` (8px) | `rounded-2xl` (16px) |
| Modals | `rounded-xl` (12px) | `rounded-2xl` (16px) |
| Inputs, buttons | `rounded-md` (6px) | `rounded-xl` (12px) |
| Badges/tags | `rounded` (4px) | `rounded-lg` (8px) |
| Icon buttons | `rounded` (4px) | `rounded-lg` (8px) |

## Layout & Spacing

### Structure (unchanged)

```
sidebar | main workspace | side panel
```

### Spacing Changes

| Area | Old | New |
|------|-----|-----|
| Page padding | `p-4` | `p-5` |
| Card padding | `p-3` | `p-4` |
| Card gap | `space-y-2` | `space-y-3` |
| Kanban gap | `gap-4` | `gap-5` |
| Modal padding | `p-5` | `p-6` |

### TopBar

- Remove visible border-bottom — rely on negative space
- Date: `text-secondary` (#a3a3a3)
- "New Task" button: primary style

### Sidebar

- Same widths: `w-48` / `w-14`
- Background: `var(--color-bg)` (same as page — not elevated)
- Active nav: `bg-white/8 text-white rounded-xl`
- Brand color: `#e5e5e5` (was indigo-400)

### Scrollbar

- Thumb: `#232323` → hover `#2a2a2a`

## Transitions & Interactions

- Base: `transition-all duration-300` on cards (wstech's smooth feel)
- Hover: background + border shift (subtle)
- Drag/drop: unchanged logic
- No new animations

## Pomodoro Timer (Monochrome)

Ring colors by session type:
- Focus: `#e5e5e5` (bright)
- Short break: `#737373` (medium gray)
- Long break: `#a3a3a3` (lighter gray)

Session labels use uppercase + tracking-[0.15em] for differentiation.

## Migration Notes

- Define CSS variables in `globals.css` under `:root`
- Replace hardcoded `zinc-*` classes with CSS variable references throughout all components
- Update `layout.tsx` to import Outfit font instead of Inter
- Update `constants.ts` only if priority colors change (they don't)
- All component files need border-radius and spacing updates

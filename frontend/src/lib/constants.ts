export const PRIORITIES = [
  { value: "low", label: "Low", color: "#6b7280" },
  { value: "medium", label: "Medium", color: "#f59e0b" },
  { value: "high", label: "High", color: "#f97316" },
  { value: "urgent", label: "Urgent", color: "#ef4444" },
] as const;

export const AREAS = [
  { value: "work", label: "Work" },
  { value: "personal", label: "Personal" },
  { value: "study", label: "Study" },
] as const;

export const KANBAN_STATUSES = [
  { value: "todo", label: "To Do" },
  { value: "in_progress", label: "In Progress" },
  { value: "done", label: "Done" },
] as const;

export type Priority = (typeof PRIORITIES)[number]["value"];
export type Area = (typeof AREAS)[number]["value"];
export type KanbanStatus = (typeof KANBAN_STATUSES)[number]["value"];

// Drag & Drop
export const DRAG_ACTIVATION_DISTANCE = 5;

// Time Block defaults
export const DEFAULT_TIMEBLOCK_MINUTES = 30;

// Calendar
export const CALENDAR_START_HOUR = 6;
export const CALENDAR_END_HOUR = 22;
export const CALENDAR_SNAP_MINUTES = 15;
export const MIN_TIMEBLOCK_MINUTES = 15;

// Toast
export const TOAST_DURATION_MS = 4000;

// Notes
export const NOTES_DEBOUNCE_MS = 500;

// Pomodoro
export const POMODOROS_BEFORE_LONG_BREAK = 4;
export const POMODORO_DURATIONS: Record<string, number> = {
  focus: 25 * 60,
  short_break: 5 * 60,
  long_break: 15 * 60,
};

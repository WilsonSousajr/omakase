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

export const PROJECT_STATUSES = [
  { value: "active", label: "Active" },
  { value: "paused", label: "Paused" },
  { value: "completed", label: "Completed" },
  { value: "archived", label: "Archived" },
] as const;

export const SEMESTER_STATUSES = [
  { value: "active", label: "Active" },
  { value: "completed", label: "Completed" },
  { value: "archived", label: "Archived" },
] as const;

export const DISCIPLINE_STATUSES = [
  { value: "active", label: "Active" },
  { value: "completed", label: "Completed" },
  { value: "dropped", label: "Dropped" },
] as const;

export const STUDY_BLOCK_TYPES = [
  { value: "theory", label: "Theory" },
  { value: "exercises", label: "Exercises" },
  { value: "review", label: "Review" },
  { value: "assignment", label: "Assignment" },
  { value: "exam_prep", label: "Exam Prep" },
  { value: "lab", label: "Lab" },
  { value: "reading", label: "Reading" },
] as const;

export const STUDY_BLOCK_STATUSES = [
  { value: "planned", label: "Planned" },
  { value: "in_progress", label: "In Progress" },
  { value: "completed", label: "Completed" },
  { value: "skipped", label: "Skipped" },
] as const;

export type Priority = (typeof PRIORITIES)[number]["value"];
export type Area = (typeof AREAS)[number]["value"];
export type KanbanStatus = (typeof KANBAN_STATUSES)[number]["value"];
export type ProjectStatus = (typeof PROJECT_STATUSES)[number]["value"];
export type SemesterStatus = (typeof SEMESTER_STATUSES)[number]["value"];
export type DisciplineStatus = (typeof DISCIPLINE_STATUSES)[number]["value"];
export type StudyBlockType = (typeof STUDY_BLOCK_TYPES)[number]["value"];
export type StudyBlockStatus = (typeof STUDY_BLOCK_STATUSES)[number]["value"];

export const CLASS_TYPES = [
  { value: "lecture", label: "Lecture" },
  { value: "lab", label: "Lab" },
  { value: "tutorial", label: "Tutorial" },
  { value: "seminar", label: "Seminar" },
] as const;

export const DAYS_OF_WEEK = [
  { value: 0, label: "Monday" },
  { value: 1, label: "Tuesday" },
  { value: 2, label: "Wednesday" },
  { value: 3, label: "Thursday" },
  { value: 4, label: "Friday" },
  { value: 5, label: "Saturday" },
  { value: 6, label: "Sunday" },
] as const;

export type ClassType = (typeof CLASS_TYPES)[number]["value"];

export const COLOR_PRESETS = [
  { value: "#ef4444", label: "Red" },
  { value: "#f97316", label: "Orange" },
  { value: "#f59e0b", label: "Amber" },
  { value: "#84cc16", label: "Lime" },
  { value: "#22c55e", label: "Green" },
  { value: "#14b8a6", label: "Teal" },
  { value: "#06b6d4", label: "Cyan" },
  { value: "#3b82f6", label: "Blue" },
  { value: "#6366f1", label: "Indigo" },
  { value: "#8b5cf6", label: "Violet" },
  { value: "#d946ef", label: "Fuchsia" },
  { value: "#ec4899", label: "Pink" },
  { value: "#a3a3a3", label: "Gray" },
] as const;

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

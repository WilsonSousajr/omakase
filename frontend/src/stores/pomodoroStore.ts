import { create } from "zustand";
import { POMODORO_DURATIONS, POMODOROS_BEFORE_LONG_BREAK } from "@/lib/constants";

type SessionType = "focus" | "short_break" | "long_break";

const DEFAULT_DURATIONS = POMODORO_DURATIONS as Record<SessionType, number>;

interface PomodoroState {
  sessionType: SessionType;
  timeRemaining: number;
  isRunning: boolean;
  completedPomodoros: number;
  intervalId: ReturnType<typeof setInterval> | null;
  durations: Record<SessionType, number>;
  pomodorosBeforeLongBreak: number;

  start: () => void;
  pause: () => void;
  reset: () => void;
  tick: () => void;
  switchSession: (type: SessionType) => void;
  setDurations: (durations: Partial<Record<SessionType, number>>, pomodorosBeforeLongBreak?: number) => void;
  onComplete: (() => void) | null;
  setOnComplete: (cb: (() => void) | null) => void;
}

export const usePomodoroStore = create<PomodoroState>((set, get) => ({
  sessionType: "focus",
  timeRemaining: DEFAULT_DURATIONS.focus,
  isRunning: false,
  completedPomodoros: 0,
  intervalId: null,
  durations: { ...DEFAULT_DURATIONS },
  pomodorosBeforeLongBreak: POMODOROS_BEFORE_LONG_BREAK,
  onComplete: null,

  setOnComplete: (cb) => set({ onComplete: cb }),

  setDurations: (newDurations, pomodorosBeforeLongBreak) => {
    const { isRunning, sessionType, durations } = get();
    const merged = { ...durations, ...newDurations };
    const updates: Partial<PomodoroState> = { durations: merged };
    if (pomodorosBeforeLongBreak !== undefined) {
      updates.pomodorosBeforeLongBreak = pomodorosBeforeLongBreak;
    }
    // Only update timeRemaining if timer is not running
    if (!isRunning) {
      updates.timeRemaining = merged[sessionType];
    }
    set(updates);
  },

  start: () => {
    const { isRunning } = get();
    if (isRunning) return;
    const intervalId = setInterval(() => get().tick(), 1000);
    set({ isRunning: true, intervalId });
  },

  pause: () => {
    const { intervalId } = get();
    if (intervalId) clearInterval(intervalId);
    set({ isRunning: false, intervalId: null });
  },

  reset: () => {
    const { intervalId, sessionType, durations } = get();
    if (intervalId) clearInterval(intervalId);
    set({
      isRunning: false,
      intervalId: null,
      timeRemaining: durations[sessionType],
    });
  },

  tick: () => {
    const {
      timeRemaining,
      sessionType,
      completedPomodoros,
      onComplete,
      durations,
      pomodorosBeforeLongBreak,
    } = get();
    if (timeRemaining <= 1) {
      const { intervalId } = get();
      if (intervalId) clearInterval(intervalId);

      const isWork = sessionType === "focus";
      const newCompleted = isWork ? completedPomodoros + 1 : completedPomodoros;
      const nextType: SessionType = isWork
        ? newCompleted % pomodorosBeforeLongBreak === 0
          ? "long_break"
          : "short_break"
        : "focus";

      set({
        isRunning: false,
        intervalId: null,
        completedPomodoros: newCompleted,
        sessionType: nextType,
        timeRemaining: durations[nextType],
      });

      onComplete?.();
    } else {
      set({ timeRemaining: timeRemaining - 1 });
    }
  },

  switchSession: (type) => {
    const { intervalId, durations } = get();
    if (intervalId) clearInterval(intervalId);
    set({
      sessionType: type,
      timeRemaining: durations[type],
      isRunning: false,
      intervalId: null,
    });
  },
}));

import { create } from "zustand";

type SessionType = "focus" | "short_break" | "long_break";

const DURATIONS: Record<SessionType, number> = {
  focus: 25 * 60,
  short_break: 5 * 60,
  long_break: 15 * 60,
};

interface PomodoroState {
  sessionType: SessionType;
  timeRemaining: number;
  isRunning: boolean;
  completedPomodoros: number;
  intervalId: ReturnType<typeof setInterval> | null;

  start: () => void;
  pause: () => void;
  reset: () => void;
  tick: () => void;
  switchSession: (type: SessionType) => void;
  onComplete: (() => void) | null;
  setOnComplete: (cb: (() => void) | null) => void;
}

export const usePomodoroStore = create<PomodoroState>((set, get) => ({
  sessionType: "focus",
  timeRemaining: DURATIONS.focus,
  isRunning: false,
  completedPomodoros: 0,
  intervalId: null,
  onComplete: null,

  setOnComplete: (cb) => set({ onComplete: cb }),

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
    const { intervalId, sessionType } = get();
    if (intervalId) clearInterval(intervalId);
    set({
      isRunning: false,
      intervalId: null,
      timeRemaining: DURATIONS[sessionType],
    });
  },

  tick: () => {
    const { timeRemaining, sessionType, completedPomodoros, onComplete } = get();
    if (timeRemaining <= 1) {
      const { intervalId } = get();
      if (intervalId) clearInterval(intervalId);

      const isWork = sessionType === "focus";
      const newCompleted = isWork ? completedPomodoros + 1 : completedPomodoros;
      const nextType: SessionType = isWork
        ? newCompleted % 4 === 0
          ? "long_break"
          : "short_break"
        : "focus";

      set({
        isRunning: false,
        intervalId: null,
        completedPomodoros: newCompleted,
        sessionType: nextType,
        timeRemaining: DURATIONS[nextType],
      });

      onComplete?.();
    } else {
      set({ timeRemaining: timeRemaining - 1 });
    }
  },

  switchSession: (type) => {
    const { intervalId } = get();
    if (intervalId) clearInterval(intervalId);
    set({
      sessionType: type,
      timeRemaining: DURATIONS[type],
      isRunning: false,
      intervalId: null,
    });
  },
}));

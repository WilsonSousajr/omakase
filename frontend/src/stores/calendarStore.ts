import { create } from "zustand";

type ViewMode = "day" | "week";

interface CalendarState {
  selectedDate: Date;
  viewMode: ViewMode;
  setSelectedDate: (date: Date) => void;
  setViewMode: (mode: ViewMode) => void;
  goToToday: () => void;
  goForward: () => void;
  goBack: () => void;
}

export const useCalendarStore = create<CalendarState>((set, get) => ({
  selectedDate: new Date(),
  viewMode: "day",

  setSelectedDate: (date) => set({ selectedDate: date }),
  setViewMode: (mode) => set({ viewMode: mode }),
  goToToday: () => set({ selectedDate: new Date() }),

  goForward: () => {
    const { selectedDate, viewMode } = get();
    const next = new Date(selectedDate);
    next.setDate(next.getDate() + (viewMode === "week" ? 7 : 1));
    set({ selectedDate: next });
  },

  goBack: () => {
    const { selectedDate, viewMode } = get();
    const prev = new Date(selectedDate);
    prev.setDate(prev.getDate() - (viewMode === "week" ? 7 : 1));
    set({ selectedDate: prev });
  },
}));

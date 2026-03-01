import { describe, it, expect, beforeEach } from "vitest";
import { useCalendarStore } from "../calendarStore";

describe("calendarStore", () => {
  beforeEach(() => {
    useCalendarStore.setState({
      selectedDate: new Date(2025, 0, 15), // Jan 15, 2025
      viewMode: "day",
    });
  });

  it("has correct initial state shape", () => {
    const state = useCalendarStore.getState();
    expect(state.selectedDate).toBeInstanceOf(Date);
    expect(state.viewMode).toBe("day");
  });

  it("sets view mode", () => {
    useCalendarStore.getState().setViewMode("week");
    expect(useCalendarStore.getState().viewMode).toBe("week");
  });

  it("goes forward one day in day mode", () => {
    useCalendarStore.getState().goForward();
    expect(useCalendarStore.getState().selectedDate.getDate()).toBe(16);
  });

  it("goes forward seven days in week mode", () => {
    useCalendarStore.getState().setViewMode("week");
    useCalendarStore.getState().goForward();
    expect(useCalendarStore.getState().selectedDate.getDate()).toBe(22);
  });

  it("goes back one day in day mode", () => {
    useCalendarStore.getState().goBack();
    expect(useCalendarStore.getState().selectedDate.getDate()).toBe(14);
  });

  it("goes back seven days in week mode", () => {
    useCalendarStore.getState().setViewMode("week");
    useCalendarStore.getState().goBack();
    expect(useCalendarStore.getState().selectedDate.getDate()).toBe(8);
  });

  it("goToToday resets to today", () => {
    useCalendarStore.getState().goToToday();
    const today = new Date();
    const selected = useCalendarStore.getState().selectedDate;
    expect(selected.getFullYear()).toBe(today.getFullYear());
    expect(selected.getMonth()).toBe(today.getMonth());
    expect(selected.getDate()).toBe(today.getDate());
  });
});

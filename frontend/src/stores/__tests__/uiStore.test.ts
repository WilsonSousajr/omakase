import { describe, it, expect, beforeEach } from "vitest";
import { useUIStore } from "../uiStore";

describe("uiStore", () => {
  beforeEach(() => {
    useUIStore.setState({
      sidebarOpen: true,
      modalOpen: null,
      activeTaskId: null,
    });
  });

  it("toggles sidebar", () => {
    expect(useUIStore.getState().sidebarOpen).toBe(true);
    useUIStore.getState().toggleSidebar();
    expect(useUIStore.getState().sidebarOpen).toBe(false);
    useUIStore.getState().toggleSidebar();
    expect(useUIStore.getState().sidebarOpen).toBe(true);
  });

  it("opens modal", () => {
    useUIStore.getState().openModal("task-form");
    expect(useUIStore.getState().modalOpen).toBe("task-form");
  });

  it("closes modal", () => {
    useUIStore.getState().openModal("task-form");
    useUIStore.getState().closeModal();
    expect(useUIStore.getState().modalOpen).toBeNull();
  });

  it("sets active task id", () => {
    useUIStore.getState().setActiveTaskId("abc-123");
    expect(useUIStore.getState().activeTaskId).toBe("abc-123");
  });

  it("clears active task id", () => {
    useUIStore.getState().setActiveTaskId("abc-123");
    useUIStore.getState().setActiveTaskId(null);
    expect(useUIStore.getState().activeTaskId).toBeNull();
  });
});

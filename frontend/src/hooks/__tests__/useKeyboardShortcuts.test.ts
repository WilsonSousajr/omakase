import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useKeyboardShortcuts } from "../useKeyboardShortcuts";
import { useUIStore } from "@/stores/uiStore";
import { usePomodoroStore } from "@/stores/pomodoroStore";

describe("useKeyboardShortcuts", () => {
  beforeEach(() => {
    useUIStore.setState({ modalOpen: null, sidebarOpen: true });
    usePomodoroStore.setState({ isRunning: false });
  });

  afterEach(() => {
    // Clean up any intervals left by pomodoro start
    const { intervalId } = usePomodoroStore.getState();
    if (intervalId) clearInterval(intervalId);
    usePomodoroStore.setState({ isRunning: false, intervalId: null });
  });

  it("N key opens task-form modal", () => {
    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "n" }));
    });

    expect(useUIStore.getState().modalOpen).toBe("task-form");
  });

  it("Escape closes modal when open", () => {
    useUIStore.setState({ modalOpen: "task-form" });
    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    });

    expect(useUIStore.getState().modalOpen).toBeNull();
  });

  it("Escape does nothing when no modal is open", () => {
    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    });

    expect(useUIStore.getState().modalOpen).toBeNull();
  });

  it("Space does not start pomodoro when not running (requires UI start)", () => {
    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: " " }));
    });

    // Space no longer starts a new session — user must click Start to create a backend session
    expect(usePomodoroStore.getState().isRunning).toBe(false);
  });

  it("Space resumes pomodoro when paused mid-session", () => {
    // Simulate a paused mid-session state (timeRemaining < full duration)
    const { durations } = usePomodoroStore.getState();
    usePomodoroStore.setState({ isRunning: false, timeRemaining: durations.focus - 60 });
    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: " " }));
    });

    expect(usePomodoroStore.getState().isRunning).toBe(true);
  });

  it("Space pauses pomodoro when running", () => {
    // Start the pomodoro first via the store
    usePomodoroStore.getState().start();
    expect(usePomodoroStore.getState().isRunning).toBe(true);

    renderHook(() => useKeyboardShortcuts());

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: " " }));
    });

    expect(usePomodoroStore.getState().isRunning).toBe(false);
  });

  it("keys are ignored when target is an input element", () => {
    renderHook(() => useKeyboardShortcuts());

    const input = document.createElement("input");
    document.body.appendChild(input);

    act(() => {
      input.dispatchEvent(
        new KeyboardEvent("keydown", { key: "n", bubbles: true })
      );
    });

    expect(useUIStore.getState().modalOpen).toBeNull();

    document.body.removeChild(input);
  });

  it("cleanup removes listener on unmount", () => {
    const { unmount } = renderHook(() => useKeyboardShortcuts());

    unmount();

    act(() => {
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "n" }));
    });

    expect(useUIStore.getState().modalOpen).toBeNull();
  });
});

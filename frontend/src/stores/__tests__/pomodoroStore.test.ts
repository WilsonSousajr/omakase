import { describe, it, expect, beforeEach, vi } from "vitest";
import { usePomodoroStore } from "../pomodoroStore";
import { POMODORO_DURATIONS, POMODOROS_BEFORE_LONG_BREAK } from "@/lib/constants";

describe("pomodoroStore", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    usePomodoroStore.setState({
      sessionType: "focus",
      timeRemaining: POMODORO_DURATIONS.focus,
      isRunning: false,
      completedPomodoros: 0,
      intervalId: null,
      onComplete: null,
    });
  });

  afterEach(() => {
    // Clean up any intervals
    const { intervalId } = usePomodoroStore.getState();
    if (intervalId) clearInterval(intervalId);
    vi.useRealTimers();
  });

  it("has correct initial state", () => {
    const state = usePomodoroStore.getState();
    expect(state.sessionType).toBe("focus");
    expect(state.timeRemaining).toBe(POMODORO_DURATIONS.focus);
    expect(state.isRunning).toBe(false);
    expect(state.completedPomodoros).toBe(0);
  });

  it("start sets running", () => {
    usePomodoroStore.getState().start();
    const state = usePomodoroStore.getState();
    expect(state.isRunning).toBe(true);
    expect(state.intervalId).not.toBeNull();
  });

  it("start is noop when already running", () => {
    usePomodoroStore.getState().start();
    const firstIntervalId = usePomodoroStore.getState().intervalId;
    usePomodoroStore.getState().start();
    expect(usePomodoroStore.getState().intervalId).toBe(firstIntervalId);
  });

  it("pause clears interval", () => {
    usePomodoroStore.getState().start();
    usePomodoroStore.getState().pause();
    const state = usePomodoroStore.getState();
    expect(state.isRunning).toBe(false);
    expect(state.intervalId).toBeNull();
  });

  it("reset restores duration", () => {
    usePomodoroStore.getState().start();
    usePomodoroStore.getState().tick();
    usePomodoroStore.getState().reset();
    expect(usePomodoroStore.getState().timeRemaining).toBe(POMODORO_DURATIONS.focus);
    expect(usePomodoroStore.getState().isRunning).toBe(false);
  });

  it("tick decrements time remaining", () => {
    const initial = usePomodoroStore.getState().timeRemaining;
    usePomodoroStore.getState().tick();
    expect(usePomodoroStore.getState().timeRemaining).toBe(initial - 1);
  });

  it("tick completes focus to short break", () => {
    usePomodoroStore.setState({ timeRemaining: 1 });
    usePomodoroStore.getState().tick();
    const state = usePomodoroStore.getState();
    expect(state.sessionType).toBe("short_break");
    expect(state.timeRemaining).toBe(POMODORO_DURATIONS.short_break);
    expect(state.completedPomodoros).toBe(1);
  });

  it("tick completes 4th focus to long break", () => {
    usePomodoroStore.setState({
      timeRemaining: 1,
      completedPomodoros: POMODOROS_BEFORE_LONG_BREAK - 1,
    });
    usePomodoroStore.getState().tick();
    expect(usePomodoroStore.getState().sessionType).toBe("long_break");
  });

  it("tick completes break to focus", () => {
    usePomodoroStore.setState({
      sessionType: "short_break",
      timeRemaining: 1,
    });
    usePomodoroStore.getState().tick();
    expect(usePomodoroStore.getState().sessionType).toBe("focus");
  });

  it("switchSession resets timer to new session duration", () => {
    usePomodoroStore.getState().start();
    usePomodoroStore.getState().switchSession("long_break");
    const state = usePomodoroStore.getState();
    expect(state.sessionType).toBe("long_break");
    expect(state.timeRemaining).toBe(POMODORO_DURATIONS.long_break);
    expect(state.isRunning).toBe(false);
  });

  it("onComplete callback fires when timer hits 0", () => {
    const callback = vi.fn();
    usePomodoroStore.getState().setOnComplete(callback);
    usePomodoroStore.setState({ timeRemaining: 1 });
    usePomodoroStore.getState().tick();
    expect(callback).toHaveBeenCalledOnce();
  });
});

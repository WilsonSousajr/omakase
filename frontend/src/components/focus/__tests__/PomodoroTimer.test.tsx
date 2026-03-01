import { describe, it, expect, vi, beforeAll, afterAll, afterEach, beforeEach } from "vitest";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { usePomodoroStore } from "@/stores/pomodoroStore";
import { useUIStore } from "@/stores/uiStore";
import { POMODORO_DURATIONS } from "@/lib/constants";
import PomodoroTimer from "../PomodoroTimer";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  const { intervalId } = usePomodoroStore.getState();
  if (intervalId) clearInterval(intervalId);
});
afterAll(() => server.close());

// Mock AudioContext
vi.stubGlobal("AudioContext", vi.fn(() => ({
  state: "running",
  resume: vi.fn(),
  close: vi.fn(),
  destination: {},
  currentTime: 0,
  createOscillator: () => ({
    connect: vi.fn(),
    frequency: { value: 0 },
    start: vi.fn(),
    stop: vi.fn(),
  }),
  createGain: () => ({
    connect: vi.fn(),
    gain: { value: 0, exponentialRampToValueAtTime: vi.fn() },
  }),
})));

describe("PomodoroTimer", () => {
  beforeEach(() => {
    usePomodoroStore.setState({
      sessionType: "focus",
      timeRemaining: POMODORO_DURATIONS.focus,
      isRunning: false,
      completedPomodoros: 0,
      intervalId: null,
      onComplete: null,
    });
    useUIStore.setState({ activeTaskId: null });
  });

  it("renders timer display in MM:SS format", () => {
    renderWithProviders(<PomodoroTimer />);
    expect(screen.getByText("25:00")).toBeInTheDocument();
  });

  it("renders session type tabs", () => {
    renderWithProviders(<PomodoroTimer />);
    // "Focus" appears in both tab and timer label, so use getAllByText
    expect(screen.getAllByText("Focus").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText("Short Break")).toBeInTheDocument();
    expect(screen.getByText("Long Break")).toBeInTheDocument();
  });

  it("switch session type via tab click", async () => {
    const user = userEvent.setup();
    renderWithProviders(<PomodoroTimer />);

    await user.click(screen.getByText("Short Break"));
    expect(usePomodoroStore.getState().sessionType).toBe("short_break");

    // Timer should show short break duration (5:00)
    expect(screen.getByText("05:00")).toBeInTheDocument();
  });

  it("shows completed pomodoro count", () => {
    usePomodoroStore.setState({ completedPomodoros: 3 });
    renderWithProviders(<PomodoroTimer />);
    expect(screen.getByText("#3")).toBeInTheDocument();
  });

  it("reset button resets timer", async () => {
    const user = userEvent.setup();
    usePomodoroStore.setState({ timeRemaining: 100 });
    renderWithProviders(<PomodoroTimer />);

    // Click reset button (RotateCcw icon)
    const buttons = screen.getAllByRole("button");
    // Reset is the first control button (after the 3 session tabs)
    const resetButton = buttons[3]; // tabs are 0,1,2 — reset is 3
    await user.click(resetButton);

    expect(usePomodoroStore.getState().timeRemaining).toBe(POMODORO_DURATIONS.focus);
  });
});

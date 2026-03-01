import { describe, it, expect, vi, beforeAll, afterAll, afterEach, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { renderWithProviders } from "@/test/utils";
import { handlers, createMockTask } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import ActiveTaskPanel from "../ActiveTaskPanel";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Mock AudioContext for PomodoroTimer
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

const TASK_ID = "test-task-id";
const API_URL = "http://localhost:8000/api/v1";

describe("ActiveTaskPanel", () => {
  beforeEach(() => {
    useUIStore.setState({ activeTaskId: null });
  });

  it("shows placeholder when no active task", () => {
    renderWithProviders(<ActiveTaskPanel />);
    expect(screen.getByText("Select a task from the kanban board")).toBeInTheDocument();
  });

  it("shows task details when activeTaskId is set", async () => {
    const task = createMockTask({
      id: TASK_ID,
      title: "Implement feature",
      description: "A detailed description",
    });

    server.use(
      http.get(`${API_URL}/tasks/${TASK_ID}/`, () =>
        HttpResponse.json(task)
      )
    );

    useUIStore.setState({ activeTaskId: TASK_ID });
    renderWithProviders(<ActiveTaskPanel />);

    await waitFor(() => {
      expect(screen.getByText("Implement feature")).toBeInTheDocument();
      expect(screen.getByText("A detailed description")).toBeInTheDocument();
    });
  });

  it("shows Notes section when task is active", async () => {
    const task = createMockTask({ id: TASK_ID, title: "Test task" });

    server.use(
      http.get(`${API_URL}/tasks/${TASK_ID}/`, () =>
        HttpResponse.json(task)
      )
    );

    useUIStore.setState({ activeTaskId: TASK_ID });
    renderWithProviders(<ActiveTaskPanel />);

    await waitFor(() => {
      expect(screen.getByText("Notes")).toBeInTheDocument();
    });
  });
});

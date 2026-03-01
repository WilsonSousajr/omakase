import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import TaskList from "../TaskList";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Mock @dnd-kit since DraggableTaskCard uses useDraggable
vi.mock("@dnd-kit/core", () => ({
  useDraggable: () => ({
    attributes: {},
    listeners: {},
    setNodeRef: vi.fn(),
    transform: null,
    isDragging: false,
  }),
}));

const API_URL = "http://localhost:8000/api/v1";

describe("TaskList", () => {
  it("shows loading skeleton", () => {
    server.use(
      http.get(`${API_URL}/tasks/`, () => new Promise(() => {}))
    );
    const { container } = renderWithProviders(<TaskList />);
    const skeletons = container.querySelectorAll(".animate-pulse");
    expect(skeletons.length).toBe(3);
  });

  it("shows empty state when no tasks", async () => {
    server.use(
      http.get(`${API_URL}/tasks/`, () =>
        HttpResponse.json({ count: 0, next: null, previous: null, results: [] })
      )
    );
    renderWithProviders(<TaskList />);
    await waitFor(() => {
      expect(screen.getByText("No tasks yet")).toBeInTheDocument();
    });
  });

  it("renders task cards when loaded", async () => {
    renderWithProviders(<TaskList />);
    await waitFor(() => {
      expect(screen.getByText("Task 1")).toBeInTheDocument();
      expect(screen.getByText("Task 2")).toBeInTheDocument();
      expect(screen.getByText("Task 3")).toBeInTheDocument();
    });
  });

  it("renders search input and priority filter", async () => {
    renderWithProviders(<TaskList />);
    expect(screen.getByPlaceholderText("Search tasks...")).toBeInTheDocument();
    expect(screen.getByDisplayValue("All priorities")).toBeInTheDocument();
  });
});

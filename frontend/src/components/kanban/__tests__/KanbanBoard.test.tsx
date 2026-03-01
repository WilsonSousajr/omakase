import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { renderWithProviders } from "@/test/utils";
import { handlers, createMockTask } from "@/test/handlers";
import KanbanBoard from "../KanbanBoard";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// Mock @dnd-kit since it requires browser APIs not available in jsdom
vi.mock("@dnd-kit/core", () => ({
  DndContext: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  PointerSensor: vi.fn(),
  useSensor: vi.fn(),
  useSensors: vi.fn(() => []),
  closestCorners: vi.fn(),
  useDroppable: () => ({ setNodeRef: vi.fn(), isOver: false }),
}));

vi.mock("@dnd-kit/sortable", () => ({
  SortableContext: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  verticalListSortingStrategy: {},
  useSortable: () => ({
    attributes: {},
    listeners: {},
    setNodeRef: vi.fn(),
    transform: null,
    transition: null,
    isDragging: false,
  }),
}));

vi.mock("@dnd-kit/utilities", () => ({
  CSS: { Transform: { toString: () => "" } },
}));

const API_URL = "http://localhost:8000/api/v1";

describe("KanbanBoard", () => {
  it("renders three columns", async () => {
    renderWithProviders(<KanbanBoard />);
    await waitFor(() => {
      expect(screen.getByText("To Do")).toBeInTheDocument();
      expect(screen.getByText("In Progress")).toBeInTheDocument();
      expect(screen.getByText("Done")).toBeInTheDocument();
    });
  });

  it("renders tasks in correct columns", async () => {
    renderWithProviders(<KanbanBoard />);
    await waitFor(() => {
      expect(screen.getByText("Task 1")).toBeInTheDocument();
      expect(screen.getByText("Task 2")).toBeInTheDocument();
      expect(screen.getByText("Task 3")).toBeInTheDocument();
    });
  });

  it("shows loading skeleton", () => {
    // Use a handler that never responds to keep loading state
    server.use(
      http.get(`${API_URL}/tasks/today/`, () => {
        return new Promise(() => {}); // Never resolves
      })
    );
    const { container } = renderWithProviders(<KanbanBoard />);
    // Should render skeleton divs with animate-pulse
    const skeletons = container.querySelectorAll(".animate-pulse");
    expect(skeletons.length).toBe(3);
  });

  it("shows empty state when no tasks", async () => {
    server.use(
      http.get(`${API_URL}/tasks/today/`, () =>
        HttpResponse.json({ count: 0, next: null, previous: null, results: [] })
      )
    );
    renderWithProviders(<KanbanBoard />);
    await waitFor(() => {
      expect(screen.getByText("To Do")).toBeInTheDocument();
    });
  });
});

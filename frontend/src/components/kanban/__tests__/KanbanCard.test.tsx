import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useUIStore } from "@/stores/uiStore";
import KanbanCard from "../KanbanCard";
import type { Task } from "@/types/task";

// Mock @dnd-kit/sortable
vi.mock("@dnd-kit/sortable", () => ({
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

const mockTask: Task = {
  id: "task-1",
  title: "Review PR",
  description: "",
  notes: "",
  priority: "urgent",
  area: "work",
  kanban_status: "in_progress",
  tags: [
    { id: "tag-1", name: "Frontend", color: "#6366f1", area: "work", created_at: "2025-01-01T00:00:00Z" },
  ],
  project: null,
  discipline: null,
  scheduled_date: null,
  due_date: null,
  estimated_minutes: null,
  kanban_order: 0,
  is_completed: false,
  completed_at: null,
  created_at: "2025-01-01T00:00:00Z",
  updated_at: "2025-01-01T00:00:00Z",
};

describe("KanbanCard", () => {
  beforeEach(() => {
    useUIStore.setState({ activeTaskId: null });
  });

  it("renders task info", () => {
    render(<KanbanCard task={mockTask} />);
    expect(screen.getByText("Review PR")).toBeInTheDocument();
    expect(screen.getByText("Urgent")).toBeInTheDocument();
    expect(screen.getByText("Frontend")).toBeInTheDocument();
  });

  it("clicking selects task in uiStore", async () => {
    const user = userEvent.setup();
    render(<KanbanCard task={mockTask} />);
    await user.click(screen.getByText("Review PR"));
    expect(useUIStore.getState().activeTaskId).toBe("task-1");
  });
});

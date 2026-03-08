import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import KanbanColumn from "../KanbanColumn";
import type { Task } from "@/types/task";

vi.mock("@dnd-kit/core", () => ({
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

const mockTask: Task = {
  id: "task-1",
  title: "Write tests",
  description: "",
  notes: "",
  priority: "medium",
  area: "work",
  kanban_status: "todo",
  tags: [],
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

describe("KanbanColumn", () => {
  it("renders column label in uppercase section-label style", () => {
    render(<KanbanColumn status="todo" label="To Do" tasks={[]} />);
    const label = screen.getByText("To Do");
    expect(label).toBeInTheDocument();
    expect(label.tagName).toBe("H3");
  });

  it("renders task count badge", () => {
    render(<KanbanColumn status="todo" label="To Do" tasks={[mockTask]} />);
    expect(screen.getByText("1")).toBeInTheDocument();
  });

  it("renders KanbanCard for each task", () => {
    const tasks = [
      mockTask,
      { ...mockTask, id: "task-2", title: "Review PR" },
    ];
    render(<KanbanColumn status="todo" label="To Do" tasks={tasks} />);
    expect(screen.getByText("Write tests")).toBeInTheDocument();
    expect(screen.getByText("Review PR")).toBeInTheDocument();
  });

  it("shows empty state when no tasks", () => {
    render(<KanbanColumn status="todo" label="To Do" tasks={[]} />);
    expect(screen.getByText("Drop tasks here")).toBeInTheDocument();
  });

  it("hides empty state when tasks exist", () => {
    render(<KanbanColumn status="todo" label="To Do" tasks={[mockTask]} />);
    expect(screen.queryByText("Drop tasks here")).not.toBeInTheDocument();
  });
});

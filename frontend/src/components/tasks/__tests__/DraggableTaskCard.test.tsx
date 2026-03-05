import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import DraggableTaskCard from "../DraggableTaskCard";
import type { Task } from "@/types/task";

vi.mock("@dnd-kit/core", () => ({
  useDraggable: () => ({
    attributes: {},
    listeners: {},
    setNodeRef: vi.fn(),
    transform: null,
    isDragging: false,
  }),
}));

const mockTask: Task = {
  id: "task-1",
  title: "Draggable Test",
  description: "",
  notes: "",
  priority: "medium",
  area: "work",
  kanban_status: "todo",
  tags: [],
  project: null,
  scheduled_date: null,
  due_date: null,
  estimated_minutes: null,
  kanban_order: 0,
  is_completed: false,
  completed_at: null,
  created_at: "2025-01-01T00:00:00Z",
  updated_at: "2025-01-01T00:00:00Z",
};

describe("DraggableTaskCard", () => {
  it("renders task title via TaskCard", () => {
    render(
      <DraggableTaskCard
        task={mockTask}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("Draggable Test")).toBeInTheDocument();
  });

  it("passes onEdit callback through", () => {
    const onEdit = vi.fn();
    render(
      <DraggableTaskCard
        task={mockTask}
        onEdit={onEdit}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    // Edit button is the second button [0]=checkbox, [1]=edit, [2]=delete
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[1]);
    expect(onEdit).toHaveBeenCalledWith(mockTask);
  });

  it("passes onDelete callback through", () => {
    const onDelete = vi.fn();
    render(
      <DraggableTaskCard
        task={mockTask}
        onEdit={vi.fn()}
        onDelete={onDelete}
        onToggleComplete={vi.fn()}
      />
    );
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[2]);
    expect(onDelete).toHaveBeenCalledWith("task-1");
  });
});

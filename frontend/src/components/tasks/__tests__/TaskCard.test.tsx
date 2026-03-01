import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import TaskCard from "../TaskCard";
import type { Task } from "@/types/task";

const mockTask: Task = {
  id: "task-1",
  title: "Write tests",
  description: "Add test coverage",
  notes: "",
  priority: "high",
  area: "work",
  kanban_status: "todo",
  tags: [
    { id: "tag-1", name: "Backend", color: "#6366f1", area: "work", created_at: "2025-01-01T00:00:00Z" },
  ],
  scheduled_date: "2025-01-15",
  due_date: null,
  estimated_minutes: null,
  kanban_order: 0,
  is_completed: false,
  completed_at: null,
  created_at: "2025-01-01T00:00:00Z",
  updated_at: "2025-01-01T00:00:00Z",
};

describe("TaskCard", () => {
  it("renders task info", () => {
    render(<TaskCard task={mockTask} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("Write tests")).toBeInTheDocument();
    expect(screen.getByText("High")).toBeInTheDocument();
    expect(screen.getByText("Backend")).toBeInTheDocument();
    expect(screen.getByText("Add test coverage")).toBeInTheDocument();
  });

  it("edit button calls onEdit", async () => {
    const user = userEvent.setup();
    const onEdit = vi.fn();
    render(<TaskCard task={mockTask} onEdit={onEdit} onDelete={vi.fn()} />);

    // Edit button has Pencil icon — find all buttons, first is edit
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[0]);
    expect(onEdit).toHaveBeenCalledWith(mockTask);
  });

  it("delete button calls onDelete", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<TaskCard task={mockTask} onEdit={vi.fn()} onDelete={onDelete} />);

    const buttons = screen.getAllByRole("button");
    await user.click(buttons[1]);
    expect(onDelete).toHaveBeenCalledWith("task-1");
  });
});

import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import TaskCard from "../TaskCard";
import type { Task } from "@/types/task";
import type { Project } from "@/types/project";

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
  project: null,
  discipline: null,
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
    render(<TaskCard task={mockTask} onEdit={vi.fn()} onDelete={vi.fn()} onToggleComplete={vi.fn()} />);
    expect(screen.getByText("Write tests")).toBeInTheDocument();
    expect(screen.getByText("High")).toBeInTheDocument();
    expect(screen.getByText("Backend")).toBeInTheDocument();
    expect(screen.getByText("Add test coverage")).toBeInTheDocument();
  });

  it("edit button calls onEdit", async () => {
    const user = userEvent.setup();
    const onEdit = vi.fn();
    render(<TaskCard task={mockTask} onEdit={onEdit} onDelete={vi.fn()} onToggleComplete={vi.fn()} />);

    // buttons: [0]=checkbox, [1]=edit, [2]=delete
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[1]);
    expect(onEdit).toHaveBeenCalledWith(mockTask);
  });

  it("delete button calls onDelete", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<TaskCard task={mockTask} onEdit={vi.fn()} onDelete={onDelete} onToggleComplete={vi.fn()} />);

    const buttons = screen.getAllByRole("button");
    await user.click(buttons[2]);
    expect(onDelete).toHaveBeenCalledWith("task-1");
  });

  it("shows project badge when task has project", () => {
    const mockProject: Project = {
      id: "proj-1",
      workspace: "ws-1",
      name: "My Project",
      description: "",
      color: "#f59e0b",
      status: "active",
      due_date: null,
      task_count: 3,
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z",
    };
    const projects = new Map([["proj-1", mockProject]]);
    const taskWithProject = { ...mockTask, project: "proj-1" };
    render(
      <TaskCard task={taskWithProject} onEdit={vi.fn()} onDelete={vi.fn()} onToggleComplete={vi.fn()} projects={projects} />
    );
    expect(screen.getByText("My Project")).toBeInTheDocument();
  });

  it("does not show project badge when task has no project", () => {
    render(<TaskCard task={mockTask} onEdit={vi.fn()} onDelete={vi.fn()} onToggleComplete={vi.fn()} />);
    expect(screen.queryByText("My Project")).not.toBeInTheDocument();
  });
});

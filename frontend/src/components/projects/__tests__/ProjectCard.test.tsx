import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ProjectCard from "../ProjectCard";
import { createMockProject } from "@/test/handlers";
import type { Project } from "@/types/project";

const mockProject = createMockProject({
  id: "proj-1",
  name: "Omakase",
  description: "Productivity app",
  color: "#f59e0b",
  task_count: 5,
  due_date: null,
}) as Project;

describe("ProjectCard", () => {
  it("renders project name and description", () => {
    render(<ProjectCard project={mockProject} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("Omakase")).toBeInTheDocument();
    expect(screen.getByText("Productivity app")).toBeInTheDocument();
  });

  it("renders task count", () => {
    render(<ProjectCard project={mockProject} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("5 tasks")).toBeInTheDocument();
  });

  it("renders singular task count", () => {
    const oneTask = { ...mockProject, task_count: 1 };
    render(<ProjectCard project={oneTask} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("1 tasks")).toBeInTheDocument();
  });

  it("renders due date when present", () => {
    const withDue = { ...mockProject, due_date: "2026-03-15" };
    render(<ProjectCard project={withDue} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("Mar 15, 2026")).toBeInTheDocument();
  });

  it("does not render due date when absent", () => {
    render(<ProjectCard project={mockProject} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.queryByText(/\d{4}/)).not.toBeInTheDocument();
  });

  it("calls onEdit when edit button clicked", async () => {
    const user = userEvent.setup();
    const onEdit = vi.fn();
    render(<ProjectCard project={mockProject} onEdit={onEdit} onDelete={vi.fn()} />);
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[0]); // edit
    expect(onEdit).toHaveBeenCalledWith(mockProject);
  });

  it("calls onDelete when delete button clicked", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<ProjectCard project={mockProject} onEdit={vi.fn()} onDelete={onDelete} />);
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[1]); // delete
    expect(onDelete).toHaveBeenCalledWith("proj-1");
  });
});

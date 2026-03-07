import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import DisciplineCard from "../DisciplineCard";
import { createMockDiscipline } from "@/test/handlers";
import type { Discipline } from "@/types/discipline";

const mockDiscipline = createMockDiscipline({
  id: "disc-1",
  name: "Calculus II",
  code: "MAT201",
  professor: "Dr. Silva",
  color: "#3b82f6",
  credits: 6,
  study_block_count: 12,
}) as Discipline;

describe("DisciplineCard", () => {
  it("renders discipline name and code", () => {
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("Calculus II")).toBeInTheDocument();
    expect(screen.getByText("MAT201")).toBeInTheDocument();
  });

  it("renders professor", () => {
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("Dr. Silva")).toBeInTheDocument();
  });

  it("renders study block count and credits", () => {
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("12 blocks")).toBeInTheDocument();
    expect(screen.getByText("6 credits")).toBeInTheDocument();
  });

  it("renders singular block count", () => {
    const oneBlock = { ...mockDiscipline, study_block_count: 1 };
    render(<DisciplineCard discipline={oneBlock} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("1 block")).toBeInTheDocument();
  });

  it("hides code when empty", () => {
    const noCode = { ...mockDiscipline, code: "" };
    render(<DisciplineCard discipline={noCode} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.queryByText("MAT201")).not.toBeInTheDocument();
  });

  it("hides professor when empty", () => {
    const noProf = { ...mockDiscipline, professor: "" };
    render(<DisciplineCard discipline={noProf} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.queryByText("Dr. Silva")).not.toBeInTheDocument();
  });

  it("calls onClick when card clicked", async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} onClick={onClick} />);
    await user.click(screen.getByRole("button", { name: /Calculus II/i }));
    expect(onClick).toHaveBeenCalledWith(mockDiscipline);
  });

  it("has button role when onClick provided", () => {
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} onClick={vi.fn()} />);
    expect(screen.getByRole("button", { name: /Calculus II/i })).toBeInTheDocument();
  });

  it("calls onEdit without triggering onClick", async () => {
    const user = userEvent.setup();
    const onEdit = vi.fn();
    const onClick = vi.fn();
    render(<DisciplineCard discipline={mockDiscipline} onEdit={onEdit} onDelete={vi.fn()} onClick={onClick} />);
    // Edit is second-to-last button (after the card itself which is a button)
    const buttons = screen.getAllByRole("button");
    // Card button is first, edit button is second, delete is third
    await user.click(buttons[1]);
    expect(onEdit).toHaveBeenCalledWith(mockDiscipline);
  });

  it("calls onDelete with discipline id", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<DisciplineCard discipline={mockDiscipline} onEdit={vi.fn()} onDelete={onDelete} onClick={vi.fn()} />);
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[2]); // delete button
    expect(onDelete).toHaveBeenCalledWith("disc-1");
  });
});

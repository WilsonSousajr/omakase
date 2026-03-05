import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import SemesterCard from "../SemesterCard";
import { createMockSemester } from "@/test/handlers";
import type { Semester } from "@/types/semester";

const mockSemester = createMockSemester({
  id: "sem-1",
  name: "2026.1",
  institution: "UnB",
  discipline_count: 6,
  start_date: "2026-03-01",
  end_date: "2026-07-15",
}) as Semester;

describe("SemesterCard", () => {
  it("renders semester name and institution", () => {
    render(<SemesterCard semester={mockSemester} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("2026.1")).toBeInTheDocument();
    expect(screen.getByText("UnB")).toBeInTheDocument();
  });

  it("renders discipline count", () => {
    render(<SemesterCard semester={mockSemester} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("6 disciplines")).toBeInTheDocument();
  });

  it("renders singular discipline count", () => {
    const oneDiscipline = { ...mockSemester, discipline_count: 1 };
    render(<SemesterCard semester={oneDiscipline} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText("1 discipline")).toBeInTheDocument();
  });

  it("renders date range", () => {
    render(<SemesterCard semester={mockSemester} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.getByText(/Mar 1/)).toBeInTheDocument();
    expect(screen.getByText(/Jul 15, 2026/)).toBeInTheDocument();
  });

  it("hides institution when empty", () => {
    const noInstitution = { ...mockSemester, institution: "" };
    render(<SemesterCard semester={noInstitution} onEdit={vi.fn()} onDelete={vi.fn()} />);
    expect(screen.queryByText("UnB")).not.toBeInTheDocument();
  });

  it("calls onEdit when edit button clicked", async () => {
    const user = userEvent.setup();
    const onEdit = vi.fn();
    render(<SemesterCard semester={mockSemester} onEdit={onEdit} onDelete={vi.fn()} />);
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[0]); // edit
    expect(onEdit).toHaveBeenCalledWith(mockSemester);
  });

  it("calls onDelete when delete button clicked", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<SemesterCard semester={mockSemester} onEdit={vi.fn()} onDelete={onDelete} />);
    const buttons = screen.getAllByRole("button");
    await user.click(buttons[1]); // delete
    expect(onDelete).toHaveBeenCalledWith("sem-1");
  });
});

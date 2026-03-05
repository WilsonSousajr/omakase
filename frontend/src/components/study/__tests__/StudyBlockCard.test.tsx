import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import StudyBlockCard from "../StudyBlockCard";
import { createMockStudyBlock, createMockDiscipline } from "@/test/handlers";
import type { Discipline } from "@/types/discipline";

const mockBlock = createMockStudyBlock({
  title: "Chapter 5 Exercises",
  block_type: "exercises",
  priority: "high",
  is_completed: false,
  scheduled_date: "2026-03-04",
});

const mockDiscipline = createMockDiscipline({
  name: "Calculo 2",
  color: "#3b82f6",
});

function makeDisciplineMap(disc: ReturnType<typeof createMockDiscipline>) {
  const map = new Map<string, Discipline>();
  map.set(disc.id as string, disc as unknown as Discipline);
  return map;
}

describe("StudyBlockCard", () => {
  it("renders study block title", () => {
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("Chapter 5 Exercises")).toBeInTheDocument();
  });

  it("renders priority badge", () => {
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("High")).toBeInTheDocument();
  });

  it("renders block type badge", () => {
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("Exercises")).toBeInTheDocument();
  });

  it("renders discipline badge when provided", () => {
    const disciplineMap = makeDisciplineMap({
      ...mockDiscipline,
      id: mockBlock.discipline,
    });
    render(
      <StudyBlockCard
        block={mockBlock as never}
        disciplines={disciplineMap}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("Calculo 2")).toBeInTheDocument();
  });

  it("renders scheduled date", () => {
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    expect(screen.getByText("Mar 4")).toBeInTheDocument();
  });

  it("calls onToggleComplete when checkbox clicked", () => {
    const onToggle = vi.fn();
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={onToggle}
      />
    );
    // The first button is the checkbox
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[0]);
    expect(onToggle).toHaveBeenCalledWith(mockBlock);
  });

  it("applies completed styles when is_completed", () => {
    const completedBlock = createMockStudyBlock({
      title: "Done Block",
      is_completed: true,
    });
    render(
      <StudyBlockCard
        block={completedBlock as never}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    const title = screen.getByText("Done Block");
    expect(title.className).toContain("line-through");
  });

  it("calls onEdit when edit button clicked", () => {
    const onEdit = vi.fn();
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={onEdit}
        onDelete={vi.fn()}
        onToggleComplete={vi.fn()}
      />
    );
    // Edit button is the second-to-last button, Delete is last
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[1]); // edit
    expect(onEdit).toHaveBeenCalledWith(mockBlock);
  });

  it("calls onDelete when delete button clicked", () => {
    const onDelete = vi.fn();
    render(
      <StudyBlockCard
        block={mockBlock as never}
        onEdit={vi.fn()}
        onDelete={onDelete}
        onToggleComplete={vi.fn()}
      />
    );
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[2]); // delete
    expect(onDelete).toHaveBeenCalledWith(mockBlock.id);
  });
});

import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import TimeBlockItem from "../TimeBlockItem";
import { createMockTimeBlock, createMockTask, createMockStudyBlock } from "@/test/handlers";
import type { TimeBlock } from "@/types/timeblock";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";

vi.mock("@dnd-kit/core", () => ({
  useDraggable: () => ({
    attributes: {},
    listeners: {},
    setNodeRef: vi.fn(),
    transform: null,
    isDragging: false,
  }),
}));

const mockBlock = createMockTimeBlock({
  id: "tb-1",
  start_time: "09:00:00",
  end_time: "10:00:00",
}) as unknown as TimeBlock;

const mockTask = createMockTask({
  id: "task-1",
  title: "Write tests",
  priority: "high",
  is_completed: false,
}) as unknown as Task;

const mockStudyBlock = createMockStudyBlock({
  id: "sb-1",
  title: "Chapter 5 Exercises",
  priority: "medium",
  is_completed: false,
}) as unknown as StudyBlock;

describe("TimeBlockItem", () => {
  it("renders task title and time range", () => {
    render(
      <TimeBlockItem
        block={mockBlock}
        task={mockTask}
        onDelete={vi.fn()}
        onResize={vi.fn()}
        slotHeight={40}
      />
    );
    expect(screen.getByText("Write tests")).toBeInTheDocument();
    expect(screen.getByText("09:00 – 10:00")).toBeInTheDocument();
  });

  it("renders priority badge for task", () => {
    render(
      <TimeBlockItem
        block={mockBlock}
        task={mockTask}
        onDelete={vi.fn()}
        onResize={vi.fn()}
        slotHeight={40}
      />
    );
    expect(screen.getByText("High")).toBeInTheDocument();
  });

  it("renders study block with BookOpen icon", () => {
    const sbBlock = { ...mockBlock, task: null, study_block: "sb-1" };
    const { container } = render(
      <TimeBlockItem
        block={sbBlock as unknown as TimeBlock}
        studyBlock={mockStudyBlock}
        disciplineColor="#3b82f6"
        onDelete={vi.fn()}
        onResize={vi.fn()}
        slotHeight={40}
      />
    );
    expect(screen.getByText("Chapter 5 Exercises")).toBeInTheDocument();
    // BookOpen icon renders as SVG
    const svgs = container.querySelectorAll("svg");
    expect(svgs.length).toBeGreaterThanOrEqual(1);
  });

  it("calls onDelete when delete button clicked", () => {
    const onDelete = vi.fn();
    render(
      <TimeBlockItem
        block={mockBlock}
        task={mockTask}
        onDelete={onDelete}
        onResize={vi.fn()}
        slotHeight={40}
      />
    );
    // Buttons: [0]=checkbox, [1]=delete (X icon)
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[1]);
    expect(onDelete).toHaveBeenCalledWith("tb-1");
  });

  it("calls onToggleComplete when checkbox clicked", () => {
    const onToggle = vi.fn();
    render(
      <TimeBlockItem
        block={mockBlock}
        task={mockTask}
        onDelete={vi.fn()}
        onResize={vi.fn()}
        onToggleComplete={onToggle}
        slotHeight={40}
      />
    );
    const buttons = screen.getAllByRole("button");
    fireEvent.click(buttons[0]); // checkbox
    expect(onToggle).toHaveBeenCalledWith("task-1", true);
  });

  it("applies line-through when completed", () => {
    const completedTask = { ...mockTask, is_completed: true };
    render(
      <TimeBlockItem
        block={mockBlock}
        task={completedTask}
        onDelete={vi.fn()}
        onResize={vi.fn()}
        slotHeight={40}
      />
    );
    const title = screen.getByText("Write tests");
    expect(title.className).toContain("line-through");
  });
});

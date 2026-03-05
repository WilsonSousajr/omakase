import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import ClassBlockItem from "../ClassBlockItem";
import { createMockClassOccurrence } from "@/test/handlers";
import type { ClassOccurrence } from "@/types/classschedule";

const mockOccurrence = createMockClassOccurrence({
  discipline_name: "Calculus II",
  discipline_color: "#3b82f6",
  class_type: "lecture",
  location: "Room 101",
  start_time: "10:00:00",
  end_time: "11:40:00",
}) as unknown as ClassOccurrence;

describe("ClassBlockItem", () => {
  it("renders discipline name and class type", () => {
    render(<ClassBlockItem occurrence={mockOccurrence} slotHeight={40} />);
    expect(screen.getByText("Calculus II")).toBeInTheDocument();
    expect(screen.getByText("lecture")).toBeInTheDocument();
  });

  it("renders time range", () => {
    render(<ClassBlockItem occurrence={mockOccurrence} slotHeight={40} />);
    expect(screen.getByText("10:00 – 11:40")).toBeInTheDocument();
  });

  it("renders location when present", () => {
    render(<ClassBlockItem occurrence={mockOccurrence} slotHeight={40} />);
    expect(screen.getByText("Room 101")).toBeInTheDocument();
  });

  it("hides location when empty", () => {
    const noLocation = { ...mockOccurrence, location: "" };
    render(<ClassBlockItem occurrence={noLocation} slotHeight={40} />);
    expect(screen.queryByText("Room 101")).not.toBeInTheDocument();
  });

  it("has dashed border styling", () => {
    const { container } = render(<ClassBlockItem occurrence={mockOccurrence} slotHeight={40} />);
    const block = container.firstChild as HTMLElement;
    expect(block.className).toContain("border-dashed");
  });

  it("renders BookOpen icon", () => {
    const { container } = render(<ClassBlockItem occurrence={mockOccurrence} slotHeight={40} />);
    const svgs = container.querySelectorAll("svg");
    expect(svgs.length).toBeGreaterThanOrEqual(1);
  });
});

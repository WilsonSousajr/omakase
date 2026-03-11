import { describe, it, expect, vi, beforeEach } from "vitest";
import { render } from "@testing-library/react";
import TimeSlot from "../TimeSlot";

const mockUseDroppable = vi.fn().mockReturnValue({
  setNodeRef: vi.fn(),
  isOver: false,
});

vi.mock("@dnd-kit/core", () => ({
  useDroppable: (...args: unknown[]) => mockUseDroppable(...args),
}));

describe("TimeSlot", () => {
  beforeEach(() => {
    mockUseDroppable.mockClear();
    mockUseDroppable.mockReturnValue({ setNodeRef: vi.fn(), isOver: false });
  });

  it("renders with correct height", () => {
    const { container } = render(
      <TimeSlot hour={9} half={0} date="2026-03-08" height={24} />
    );
    const slot = container.firstChild as HTMLElement;
    expect(slot.style.height).toBe("24px");
  });

  it("creates droppable with correct id for hour slot", () => {
    render(<TimeSlot hour={9} half={0} date="2026-03-08" height={24} />);
    expect(mockUseDroppable).toHaveBeenCalledWith({
      id: "slot-2026-03-08-09:00",
      data: { type: "timeslot", date: "2026-03-08", time: "09:00" },
    });
  });

  it("creates droppable with correct id for half-hour slot", () => {
    render(<TimeSlot hour={9} half={1} date="2026-03-08" height={24} />);
    expect(mockUseDroppable).toHaveBeenCalledWith({
      id: "slot-2026-03-08-09:30",
      data: { type: "timeslot", date: "2026-03-08", time: "09:30" },
    });
  });

  it("applies hour line border for half=0", () => {
    const { container } = render(
      <TimeSlot hour={9} half={0} date="2026-03-08" height={24} />
    );
    const slot = container.firstChild as HTMLElement;
    expect(slot.className).toContain("border-t");
  });

  it("does not apply hour line border for half=1", () => {
    const { container } = render(
      <TimeSlot hour={9} half={1} date="2026-03-08" height={24} />
    );
    const slot = container.firstChild as HTMLElement;
    expect(slot.className).not.toContain("border-t");
  });

  it("applies highlight when isOver", () => {
    mockUseDroppable.mockReturnValue({ setNodeRef: vi.fn(), isOver: true });
    const { container } = render(
      <TimeSlot hour={9} half={0} date="2026-03-08" height={24} />
    );
    const slot = container.firstChild as HTMLElement;
    expect(slot.className).toContain("bg-white/5");
  });

  it("has transition-colors for smooth drop hover", () => {
    const { container } = render(
      <TimeSlot hour={9} half={0} date="2026-03-08" height={24} />
    );
    const slot = container.firstChild as HTMLElement;
    expect(slot.className).toContain("transition-colors");
  });

  it("forwards onMouseDown handler", () => {
    const onMouseDown = vi.fn();
    const { container } = render(
      <TimeSlot hour={9} half={0} date="2026-03-08" height={24} onMouseDown={onMouseDown} />
    );
    const slot = container.firstChild as HTMLElement;
    slot.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(onMouseDown).toHaveBeenCalled();
  });
});

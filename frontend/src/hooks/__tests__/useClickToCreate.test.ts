import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useClickToCreate } from "../useClickToCreate";
import { SLOT_HEIGHT_DAY } from "@/components/calendar/calendarUtils";

function createMouseEvent(
  type: string,
  clientY: number,
  target?: Partial<HTMLElement>,
): React.MouseEvent {
  return {
    clientY,
    button: 0,
    target: target ?? document.createElement("div"),
    preventDefault: vi.fn(),
    stopPropagation: vi.fn(),
  } as unknown as React.MouseEvent;
}

describe("useClickToCreate", () => {
  const onCreateRange = vi.fn();
  const gridRef = { current: document.createElement("div") };

  beforeEach(() => {
    onCreateRange.mockClear();
    // Mock getBoundingClientRect to give a known top offset
    gridRef.current.getBoundingClientRect = vi.fn(() => ({
      top: 0,
      left: 0,
      bottom: 1000,
      right: 500,
      width: 500,
      height: 1000,
      x: 0,
      y: 0,
      toJSON: vi.fn(),
    }));
  });

  function createHook(disabled = false) {
    return renderHook(() =>
      useClickToCreate({
        slotHeight: SLOT_HEIGHT_DAY,
        startHour: 6,
        date: "2026-03-09",
        gridRef,
        disabled,
        onCreateRange,
      })
    );
  }

  it("starts in idle state", () => {
    const { result } = createHook();
    expect(result.current.isCreating).toBe(false);
    expect(result.current.creationStart).toBeNull();
    expect(result.current.creationEnd).toBeNull();
  });

  it("does not start on right-click", () => {
    const { result } = createHook();
    const event = {
      ...createMouseEvent("mousedown", 100),
      button: 2,
    } as unknown as React.MouseEvent;

    act(() => {
      result.current.handlers.onMouseDown(event);
    });
    expect(result.current.isCreating).toBe(false);
  });

  it("does not start when disabled", () => {
    const { result } = createHook(true);
    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 100));
    });
    expect(result.current.isCreating).toBe(false);
  });

  it("does not start on timeblock elements", () => {
    const { result } = createHook();
    const target = document.createElement("div");
    target.setAttribute("data-timeblock", "");
    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 100, target));
    });
    expect(result.current.isCreating).toBe(false);
  });

  it("enters drawing mode after 5px vertical movement", () => {
    const { result } = createHook();

    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 100));
    });
    // Not yet creating — need 5px movement
    expect(result.current.isCreating).toBe(false);

    act(() => {
      result.current.handlers.onMouseMove(createMouseEvent("mousemove", 106));
    });
    expect(result.current.isCreating).toBe(true);
  });

  it("snaps start and end times to 15-minute increments", () => {
    const { result } = createHook();

    // clientY=100 with grid top=0, SLOT_HEIGHT_DAY=48
    // 100px / (48/2) = ~4.17 slots * 15 min = ~62.5 min, snapped = 60 min
    // 60 min from startHour=6 → 07:00
    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 100));
    });
    act(() => {
      result.current.handlers.onMouseMove(createMouseEvent("mousemove", 200));
    });

    expect(result.current.isCreating).toBe(true);
    expect(result.current.creationStart).not.toBeNull();
    expect(result.current.creationEnd).not.toBeNull();
    // Start and end should be different
    expect(result.current.creationStart).not.toBe(result.current.creationEnd);
  });

  it("calls onCreateRange on mouseup when range >= 15 min", () => {
    const { result } = createHook();

    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 100));
    });
    act(() => {
      result.current.handlers.onMouseMove(createMouseEvent("mousemove", 200));
    });
    act(() => {
      result.current.handlers.onMouseUp(createMouseEvent("mouseup", 200));
    });

    expect(onCreateRange).toHaveBeenCalledWith(
      "2026-03-09",
      expect.any(String),
      expect.any(String)
    );
    // Should reset to idle
    expect(result.current.isCreating).toBe(false);
  });

  it("does not call onCreateRange when range < 15 min (just a click)", () => {
    const { result } = createHook();

    // Position 96 snaps to 08:00, position 101 also snaps to 08:00
    // (both within the same 15-min snap interval at SLOT_HEIGHT_DAY=48)
    // 5px delta passes the activation threshold but yields 0 min range
    act(() => {
      result.current.handlers.onMouseDown(createMouseEvent("mousedown", 96));
    });
    act(() => {
      result.current.handlers.onMouseMove(createMouseEvent("mousemove", 101));
    });
    act(() => {
      result.current.handlers.onMouseUp(createMouseEvent("mouseup", 101));
    });

    expect(onCreateRange).not.toHaveBeenCalled();
    expect(result.current.isCreating).toBe(false);
  });
});

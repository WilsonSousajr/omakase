import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import CreationOverlay from "../CreationOverlay";
import { SLOT_HEIGHT_DAY } from "../calendarUtils";

describe("CreationOverlay", () => {
  it("renders with start and end time labels", () => {
    render(
      <CreationOverlay
        startTime="09:00"
        endTime="10:00"
        slotHeight={SLOT_HEIGHT_DAY}
      />
    );
    expect(screen.getByText("9:00 AM")).toBeInTheDocument();
    expect(screen.getByText("10:00 AM")).toBeInTheDocument();
  });

  it("positions at correct offset", () => {
    const { container } = render(
      <CreationOverlay
        startTime="07:00"
        endTime="08:00"
        slotHeight={SLOT_HEIGHT_DAY}
      />
    );
    const wrapper = container.firstChild as HTMLElement;
    // 07:00 with startHour=6: (1*60)/30 * (48/2) = 2 * 24 = 48px
    expect(wrapper.style.top).toBe("48px");
  });

  it("calculates correct height", () => {
    const { container } = render(
      <CreationOverlay
        startTime="09:00"
        endTime="10:00"
        slotHeight={SLOT_HEIGHT_DAY}
      />
    );
    const wrapper = container.firstChild as HTMLElement;
    // 1 hour = 2 slots * 48/2 = 48px
    expect(wrapper.style.height).toBe("48px");
  });

  it("has translucent styling", () => {
    const { container } = render(
      <CreationOverlay
        startTime="09:00"
        endTime="10:00"
        slotHeight={SLOT_HEIGHT_DAY}
      />
    );
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper.className).toContain("rounded-xl");
  });

  it("handles PM times correctly", () => {
    render(
      <CreationOverlay
        startTime="14:30"
        endTime="15:00"
        slotHeight={SLOT_HEIGHT_DAY}
      />
    );
    expect(screen.getByText("2:30 PM")).toBeInTheDocument();
    expect(screen.getByText("3:00 PM")).toBeInTheDocument();
  });
});

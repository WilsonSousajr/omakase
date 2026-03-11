import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, act } from "@testing-library/react";
import CurrentTimeIndicator from "../CurrentTimeIndicator";
import { SLOT_HEIGHT_DAY } from "../calendarUtils";

describe("CurrentTimeIndicator", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    // Set current time to 10:30 AM
    vi.setSystemTime(new Date(2026, 2, 9, 10, 30, 0));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renders when isToday is true", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={true} />
    );
    expect(container.firstChild).not.toBeNull();
  });

  it("does not render when isToday is false", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={false} />
    );
    expect(container.firstChild).toBeNull();
  });

  it("renders the red line", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={true} />
    );
    const line = container.querySelector("[data-testid='current-time-line']");
    expect(line).not.toBeNull();
  });

  it("renders the red dot", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={true} />
    );
    const dot = container.querySelector("[data-testid='current-time-dot']");
    expect(dot).not.toBeNull();
  });

  it("positions at correct offset for 10:30 with startHour=6", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={true} />
    );
    const wrapper = container.firstChild as HTMLElement;
    // 10:30 with startHour=6: (4*60+30)/30 * (48/2) = 9 * 24 = 216px
    expect(wrapper.style.top).toBe("216px");
  });

  it("updates position every 60 seconds", () => {
    const { container } = render(
      <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={true} />
    );
    const wrapper = container.firstChild as HTMLElement;
    const initialTop = wrapper.style.top;
    expect(initialTop).toBe("216px"); // 10:30

    // Change system time to 11:00 before the interval fires
    vi.setSystemTime(new Date(2026, 2, 9, 11, 0, 0));
    act(() => {
      vi.advanceTimersByTime(60_000);
    });

    // Position should have updated from 216px
    expect(wrapper.style.top).not.toBe(initialTop);
  });
});

import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderWithProviders } from "@/test/utils";
import { useCalendarStore } from "@/stores/calendarStore";
import CalendarHeader from "../CalendarHeader";

describe("CalendarHeader", () => {
  beforeEach(() => {
    useCalendarStore.setState({
      selectedDate: new Date(2025, 5, 15), // June 15, 2025
      viewMode: "day",
    });
  });

  it("renders Today button and nav arrows", () => {
    renderWithProviders(<CalendarHeader />);
    expect(screen.getByText("Today")).toBeInTheDocument();
    // ChevronLeft and ChevronRight render as SVGs inside buttons
    const buttons = screen.getAllByRole("button");
    expect(buttons.length).toBeGreaterThanOrEqual(3); // back, today, forward
  });

  it("renders date label after hydration", async () => {
    renderWithProviders(<CalendarHeader />);
    await waitFor(() => {
      expect(screen.getByText("June 15, 2025")).toBeInTheDocument();
    });
  });

  it("renders day/week view toggle", () => {
    renderWithProviders(<CalendarHeader />);
    expect(screen.getByText("Day")).toBeInTheDocument();
    expect(screen.getByText("Week")).toBeInTheDocument();
  });

  it("clicking Today calls goToToday", async () => {
    const user = userEvent.setup();
    // Set date to something other than today
    useCalendarStore.setState({ selectedDate: new Date(2025, 0, 1) });
    renderWithProviders(<CalendarHeader />);

    await user.click(screen.getByText("Today"));

    const { selectedDate } = useCalendarStore.getState();
    const today = new Date();
    expect(selectedDate.toDateString()).toBe(today.toDateString());
  });

  it("clicking forward advances date by 1 day in day mode", async () => {
    const user = userEvent.setup();
    renderWithProviders(<CalendarHeader />);

    // The forward button is the 3rd navigation button (back, today, forward)
    const buttons = screen.getAllByRole("button");
    // Forward arrow is after Today button
    await user.click(buttons[2]);

    const { selectedDate } = useCalendarStore.getState();
    expect(selectedDate.getDate()).toBe(16);
  });

  it("clicking back moves date back by 1 day in day mode", async () => {
    const user = userEvent.setup();
    renderWithProviders(<CalendarHeader />);

    const buttons = screen.getAllByRole("button");
    // Back arrow is the first button
    await user.click(buttons[0]);

    const { selectedDate } = useCalendarStore.getState();
    expect(selectedDate.getDate()).toBe(14);
  });

  it("clicking week toggle switches view mode", async () => {
    const user = userEvent.setup();
    renderWithProviders(<CalendarHeader />);

    await user.click(screen.getByText("Week"));
    expect(useCalendarStore.getState().viewMode).toBe("week");
  });
});

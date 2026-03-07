import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import ClassScheduleForm from "../ClassScheduleForm";
import type { ClassSchedule } from "@/types/classschedule";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("ClassScheduleForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "classschedule-form" });
    renderWithProviders(<ClassScheduleForm disciplineId="disc-1" onClose={vi.fn()} />);
    expect(screen.getByText("New Class Schedule")).toBeInTheDocument();
    expect(screen.getByText("Day of week", { exact: false })).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<ClassScheduleForm disciplineId="disc-1" onClose={vi.fn()} />);
    expect(container.innerHTML).toBe("");
  });

  it("submits create class schedule", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "classschedule-form" });
    const onClose = vi.fn();
    renderWithProviders(<ClassScheduleForm disciplineId="disc-1" onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /create/i }));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "classschedule-form" });
    const editSchedule: ClassSchedule = {
      id: "cs-1",
      discipline: "disc-1",
      day_of_week: 2,
      start_time: "14:00:00",
      end_time: "15:40:00",
      class_type: "lab",
      location: "Lab Building A",
      is_active: true,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
    };

    renderWithProviders(
      <ClassScheduleForm editSchedule={editSchedule} disciplineId="disc-1" onClose={vi.fn()} />
    );

    expect(screen.getByText("Edit Class Schedule")).toBeInTheDocument();
    expect(screen.getByDisplayValue("14:00")).toBeInTheDocument();
    expect(screen.getByDisplayValue("15:40")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Lab Building A")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });

  it("shows cancel button that calls onClose", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "classschedule-form" });
    const onClose = vi.fn();
    renderWithProviders(<ClassScheduleForm disciplineId="disc-1" onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /cancel/i }));
    expect(onClose).toHaveBeenCalled();
  });
});

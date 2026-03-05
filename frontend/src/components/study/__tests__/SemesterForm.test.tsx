import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import SemesterForm from "../SemesterForm";
import type { Semester } from "@/types/semester";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("SemesterForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "semester-form" });
    renderWithProviders(<SemesterForm onClose={vi.fn()} />);
    expect(screen.getByPlaceholderText(/semester name/i)).toBeInTheDocument();
    expect(screen.getByText("New Semester")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<SemesterForm onClose={vi.fn()} />);
    expect(container.innerHTML).toBe("");
  });

  it("submit button is disabled when required fields empty", () => {
    useUIStore.setState({ modalOpen: "semester-form" });
    renderWithProviders(<SemesterForm onClose={vi.fn()} />);

    const submitBtn = screen.getByRole("button", { name: /create/i });
    expect(submitBtn).toBeDisabled();
  });

  it("name is required — empty name prevents submit", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "semester-form" });
    const onClose = vi.fn();
    renderWithProviders(<SemesterForm onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(onClose).not.toHaveBeenCalled();
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "semester-form" });
    const editSemester: Semester = {
      id: "sem-1",
      name: "2026.1",
      institution: "UnB",
      start_date: "2026-03-01",
      end_date: "2026-07-15",
      status: "active",
      discipline_count: 5,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
    };

    renderWithProviders(<SemesterForm editSemester={editSemester} onClose={vi.fn()} />);

    expect(screen.getByText("Edit Semester")).toBeInTheDocument();
    expect(screen.getByDisplayValue("2026.1")).toBeInTheDocument();
    expect(screen.getByDisplayValue("UnB")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });
});

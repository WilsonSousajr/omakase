import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import DisciplineForm from "../DisciplineForm";
import type { Discipline } from "@/types/discipline";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("DisciplineForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "discipline-form" });
    renderWithProviders(<DisciplineForm onClose={vi.fn()} />);
    expect(screen.getByPlaceholderText("Discipline name")).toBeInTheDocument();
    expect(screen.getByText("New Discipline")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<DisciplineForm onClose={vi.fn()} />);
    expect(container.innerHTML).toBe("");
  });

  it("loads semester dropdown from API", async () => {
    useUIStore.setState({ modalOpen: "discipline-form" });
    renderWithProviders(<DisciplineForm onClose={vi.fn()} />);

    await waitFor(() => {
      expect(screen.getByText("2026.1")).toBeInTheDocument();
    });
  });

  it("submits create discipline", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "discipline-form" });
    const onClose = vi.fn();
    renderWithProviders(<DisciplineForm onClose={onClose} />);

    await user.type(screen.getByPlaceholderText("Discipline name"), "Physics I");

    // Wait for semesters to load
    await waitFor(() => {
      expect(screen.getByText("2026.1")).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: /create/i }));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("name is required — empty name prevents submit", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "discipline-form" });
    const onClose = vi.fn();
    renderWithProviders(<DisciplineForm onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(onClose).not.toHaveBeenCalled();
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "discipline-form" });
    const editDiscipline: Discipline = {
      id: "disc-1",
      semester: "sem-1",
      name: "Calculus II",
      code: "MAT201",
      professor: "Dr. Silva",
      color: "#3b82f6",
      credits: 6,
      target_grade: null,
      status: "active",
      study_block_count: 12,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
    };

    renderWithProviders(<DisciplineForm editDiscipline={editDiscipline} onClose={vi.fn()} />);

    expect(screen.getByText("Edit Discipline")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Calculus II")).toBeInTheDocument();
    expect(screen.getByDisplayValue("MAT201")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });
});

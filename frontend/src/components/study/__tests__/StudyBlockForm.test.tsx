import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import StudyBlockForm from "../StudyBlockForm";
import type { StudyBlock } from "@/types/studyblock";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("StudyBlockForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "studyblock-form" });
    renderWithProviders(<StudyBlockForm onClose={vi.fn()} />);
    expect(screen.getByPlaceholderText("Study block title")).toBeInTheDocument();
    expect(screen.getByText("New Study Block")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<StudyBlockForm onClose={vi.fn()} />);
    expect(container.innerHTML).toBe("");
  });

  it("loads discipline dropdown from API", async () => {
    useUIStore.setState({ modalOpen: "studyblock-form" });
    renderWithProviders(<StudyBlockForm onClose={vi.fn()} />);

    await waitFor(() => {
      expect(screen.getByText(/Calculo 2/)).toBeInTheDocument();
    });
  });

  it("submits create study block", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "studyblock-form" });
    const onClose = vi.fn();
    renderWithProviders(<StudyBlockForm onClose={onClose} />);

    await user.type(screen.getByPlaceholderText("Study block title"), "Chapter 5 Review");

    // Wait for disciplines to load
    await waitFor(() => {
      expect(screen.getByText(/Calculo 2/)).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: /create/i }));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("title is required — empty title prevents submit", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "studyblock-form" });
    const onClose = vi.fn();
    renderWithProviders(<StudyBlockForm onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(onClose).not.toHaveBeenCalled();
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "studyblock-form" });
    const editBlock: StudyBlock = {
      id: "sb-1",
      discipline: "disc-1",
      title: "Integrals Practice",
      block_type: "exercises",
      priority: "high",
      status: "planned",
      notes: "Focus on u-substitution",
      estimated_minutes: 60,
      scheduled_date: "2026-03-10",
      due_date: null,
      is_completed: false,
      completed_at: null,
      created_at: "2026-01-01T00:00:00Z",
      updated_at: "2026-01-01T00:00:00Z",
    };

    renderWithProviders(<StudyBlockForm editStudyBlock={editBlock} onClose={vi.fn()} />);

    expect(screen.getByText("Edit Study Block")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Integrals Practice")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Focus on u-substitution")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });
});

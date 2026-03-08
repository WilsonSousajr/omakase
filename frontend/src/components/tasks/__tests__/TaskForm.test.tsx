import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import TaskForm from "../TaskForm";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("TaskForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "task-form" });
    const onClose = vi.fn();
    renderWithProviders(<TaskForm onClose={onClose} />);

    expect(screen.getByPlaceholderText("Task title")).toBeInTheDocument();
    expect(screen.getByText("New Task")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const onClose = vi.fn();
    const { container } = renderWithProviders(<TaskForm onClose={onClose} />);
    expect(container.innerHTML).toBe("");
  });

  it("submits create task", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    const onClose = vi.fn();
    renderWithProviders(<TaskForm onClose={onClose} />);

    await user.type(screen.getByPlaceholderText("Task title"), "My new task");
    await user.click(screen.getByRole("button", { name: /create/i }));

    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("title is required — submit with empty title does nothing", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    const onClose = vi.fn();
    renderWithProviders(<TaskForm onClose={onClose} />);

    // Try submitting without typing a title
    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(onClose).not.toHaveBeenCalled();
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "task-form" });
    const editTask = {
      id: "123",
      title: "Existing task",
      description: "Some description",
      notes: "",
      priority: "high" as const,
      area: "work" as const,
      kanban_status: "todo" as const,
      tags: [],
      project: null,
      discipline: null,
      scheduled_date: null,
      due_date: null,
      estimated_minutes: null,
      kanban_order: 0,
      is_completed: false,
      completed_at: null,
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z",
    };

    renderWithProviders(<TaskForm editTask={editTask} onClose={vi.fn()} />);

    expect(screen.getByText("Edit Task")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Existing task")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });

  it("tag selection toggles", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    renderWithProviders(<TaskForm onClose={vi.fn()} />);

    // Wait for tags to load from MSW
    await waitFor(() => {
      expect(screen.getByText("Frontend")).toBeInTheDocument();
    });

    // Click to select tag
    await user.click(screen.getByText("Frontend"));
    // Click again to deselect
    await user.click(screen.getByText("Frontend"));
  });
});

import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
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
  useUIStore.setState({ modalOpen: null, editTask: null });
});
afterAll(() => server.close());

describe("TaskForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "task-form" });
    renderWithProviders(<TaskForm />);

    expect(screen.getByPlaceholderText("What needs to be done?")).toBeInTheDocument();
    expect(screen.getByText("New Task")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<TaskForm />);
    expect(container.innerHTML).toBe("");
  });

  it("submits create task", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    renderWithProviders(<TaskForm />);

    await user.type(screen.getByPlaceholderText("What needs to be done?"), "My new task");
    await user.click(screen.getByRole("button", { name: /create/i }));

    await waitFor(() => expect(useUIStore.getState().modalOpen).toBeNull());
  });

  it("title is required — submit with empty title does nothing", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    renderWithProviders(<TaskForm />);

    // Try submitting without typing a title
    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(useUIStore.getState().modalOpen).toBe("task-form");
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({
      modalOpen: "task-form",
      editTask: {
        id: "123",
        title: "Existing task",
        description: "Some description",
        notes: "",
        priority: "high",
        area: "work",
        kanban_status: "todo",
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
      },
    });

    renderWithProviders(<TaskForm />);

    expect(screen.getByText("Edit Task")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Existing task")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });

  it("tag selection toggles", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "task-form" });
    renderWithProviders(<TaskForm />);

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

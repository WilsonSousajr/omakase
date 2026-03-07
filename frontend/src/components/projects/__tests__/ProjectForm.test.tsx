import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { useUIStore } from "@/stores/uiStore";
import ProjectForm from "../ProjectForm";
import type { Project } from "@/types/project";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  useUIStore.setState({ modalOpen: null });
});
afterAll(() => server.close());

describe("ProjectForm", () => {
  it("renders empty form when modal is open", () => {
    useUIStore.setState({ modalOpen: "project-form" });
    renderWithProviders(<ProjectForm onClose={vi.fn()} />);
    expect(screen.getByPlaceholderText("Project name")).toBeInTheDocument();
    expect(screen.getByText("New Project")).toBeInTheDocument();
  });

  it("does not render when modal is closed", () => {
    useUIStore.setState({ modalOpen: null });
    const { container } = renderWithProviders(<ProjectForm onClose={vi.fn()} />);
    expect(container.innerHTML).toBe("");
  });

  it("submits create project", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "project-form" });
    const onClose = vi.fn();
    renderWithProviders(<ProjectForm onClose={onClose} />);

    await user.type(screen.getByPlaceholderText("Project name"), "New Project");

    // Wait for workspaces to load from MSW
    await waitFor(() => {
      expect(screen.getByText("Work")).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: /create/i }));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("name is required — empty title prevents submit", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "project-form" });
    const onClose = vi.fn();
    renderWithProviders(<ProjectForm onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /create/i }));
    expect(onClose).not.toHaveBeenCalled();
  });

  it("renders edit mode with pre-filled data", () => {
    useUIStore.setState({ modalOpen: "project-form" });
    const editProject: Project = {
      id: "proj-1",
      workspace: "ws-1",
      name: "Existing Project",
      description: "A description",
      color: "#ff6600",
      status: "active",
      due_date: null,
      task_count: 3,
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z",
    };

    renderWithProviders(<ProjectForm editProject={editProject} onClose={vi.fn()} />);

    expect(screen.getByText("Edit Project")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Existing Project")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /update/i })).toBeInTheDocument();
  });

  it("shows cancel button that calls onClose", async () => {
    const user = userEvent.setup();
    useUIStore.setState({ modalOpen: "project-form" });
    const onClose = vi.fn();
    renderWithProviders(<ProjectForm onClose={onClose} />);

    await user.click(screen.getByRole("button", { name: /cancel/i }));
    expect(onClose).toHaveBeenCalled();
  });
});

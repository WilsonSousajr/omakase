import { describe, it, expect, vi, beforeEach } from "vitest";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import SubtaskChecklist from "../SubtaskChecklist";
import { renderWithProviders } from "@/test/utils";
import type { Subtask } from "@/types/subtask";

const mockSubtasks: Subtask[] = [
  {
    id: "sub-1",
    title: "Write unit tests",
    is_completed: true,
    order: 0,
    created_at: "2026-01-01T00:00:00Z",
  },
  {
    id: "sub-2",
    title: "Write integration tests",
    is_completed: false,
    order: 1,
    created_at: "2026-01-01T00:00:00Z",
  },
  {
    id: "sub-3",
    title: "Write e2e tests",
    is_completed: false,
    order: 2,
    created_at: "2026-01-01T00:00:00Z",
  },
];

const mockUpdateSubtask = vi.fn();
const mockCreateSubtask = vi.fn();
const mockDeleteSubtask = vi.fn();

vi.mock("@/hooks/useSubtasks", () => ({
  useSubtasks: () => ({
    data: mockSubtasks,
    isLoading: false,
  }),
  useCreateSubtask: () => ({
    mutate: mockCreateSubtask,
    isPending: false,
  }),
  useUpdateSubtask: () => ({
    mutate: mockUpdateSubtask,
    isPending: false,
  }),
  useDeleteSubtask: () => ({
    mutate: mockDeleteSubtask,
    isPending: false,
  }),
}));

describe("SubtaskChecklist", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders subtask items", () => {
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    expect(screen.getByText("Write unit tests")).toBeInTheDocument();
    expect(screen.getByText("Write integration tests")).toBeInTheDocument();
    expect(screen.getByText("Write e2e tests")).toBeInTheDocument();
  });

  it("shows completion count", () => {
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    expect(screen.getByText("1/3")).toBeInTheDocument();
  });

  it("renders checkboxes with correct checked state", () => {
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    const checkboxes = screen.getAllByRole("checkbox");
    expect(checkboxes).toHaveLength(3);
    expect(checkboxes[0]).toBeChecked();
    expect(checkboxes[1]).not.toBeChecked();
    expect(checkboxes[2]).not.toBeChecked();
  });

  it("toggles subtask completion on checkbox click", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    const checkboxes = screen.getAllByRole("checkbox");
    await user.click(checkboxes[1]);
    expect(mockUpdateSubtask).toHaveBeenCalledWith({
      id: "sub-2",
      is_completed: true,
    });
  });

  it("adds a subtask on Enter in the input", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    const input = screen.getByPlaceholderText("Add subtask...");
    await user.type(input, "New subtask{Enter}");
    expect(mockCreateSubtask).toHaveBeenCalledWith({ title: "New subtask" });
  });

  it("does not add a subtask if input is empty", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    const input = screen.getByPlaceholderText("Add subtask...");
    await user.type(input, "{Enter}");
    expect(mockCreateSubtask).not.toHaveBeenCalled();
  });

  it("shows delete button and calls delete on click", async () => {
    const user = userEvent.setup();
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    // Delete buttons are the X buttons for each subtask
    const deleteButtons = screen.getAllByLabelText("Delete subtask");
    expect(deleteButtons).toHaveLength(3);
    await user.click(deleteButtons[0]);
    expect(mockDeleteSubtask).toHaveBeenCalledWith("sub-1");
  });

  it("shows section label", () => {
    renderWithProviders(<SubtaskChecklist taskId="task-1" />);
    expect(screen.getByText("Subtasks")).toBeInTheDocument();
  });
});

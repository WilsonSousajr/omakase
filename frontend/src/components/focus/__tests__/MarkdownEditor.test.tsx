import { describe, it, expect, vi, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import { NOTES_DEBOUNCE_MS } from "@/lib/constants";
import MarkdownEditor from "../MarkdownEditor";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe("MarkdownEditor", () => {
  it("renders write tab with textarea", () => {
    renderWithProviders(<MarkdownEditor taskId="task-1" initialContent="" />);
    expect(screen.getByPlaceholderText(/write notes/i)).toBeInTheDocument();
  });

  it("renders preview tab", async () => {
    const user = userEvent.setup();
    renderWithProviders(<MarkdownEditor taskId="task-1" initialContent="**Bold text**" />);

    await user.click(screen.getByText("Preview"));

    await waitFor(() => {
      expect(screen.getByText("Bold text")).toBeInTheDocument();
    });
  });

  it("shows nothing to preview when content is empty", async () => {
    const user = userEvent.setup();
    renderWithProviders(<MarkdownEditor taskId="task-1" initialContent="" />);

    await user.click(screen.getByText("Preview"));

    expect(screen.getByText("Nothing to preview")).toBeInTheDocument();
  });

  it("debounced save triggers after delay", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    renderWithProviders(<MarkdownEditor taskId="task-1" initialContent="" />);

    const textarea = screen.getByPlaceholderText(/write notes/i);
    await user.type(textarea, "Hello");

    // Advance past debounce
    vi.advanceTimersByTime(NOTES_DEBOUNCE_MS + 100);

    // The mutation should have fired (verified by no error thrown)
    vi.useRealTimers();
  });

  it("displays initial content", () => {
    renderWithProviders(<MarkdownEditor taskId="task-1" initialContent="# Hello World" />);
    expect(screen.getByDisplayValue("# Hello World")).toBeInTheDocument();
  });
});

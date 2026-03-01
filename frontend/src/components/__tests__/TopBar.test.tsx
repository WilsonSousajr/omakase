import { describe, it, expect, beforeEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderWithProviders } from "@/test/utils";
import { useUIStore } from "@/stores/uiStore";
import TopBar from "../TopBar";

describe("TopBar", () => {
  beforeEach(() => {
    useUIStore.setState({ modalOpen: null, sidebarOpen: true });
  });

  it("renders New Task button", () => {
    renderWithProviders(<TopBar />);

    expect(screen.getByText("New Task")).toBeInTheDocument();
  });

  it("New Task button opens task-form modal", async () => {
    const user = userEvent.setup();
    renderWithProviders(<TopBar />);

    const button = screen.getByText("New Task").closest("button")!;
    await user.click(button);

    expect(useUIStore.getState().modalOpen).toBe("task-form");
  });

  it("renders date string after effect runs", async () => {
    renderWithProviders(<TopBar />);

    await waitFor(() => {
      // The date string is formatted as "EEEE, MMMM d" (e.g., "Saturday, February 28")
      // We check that *some* date text appears (not empty)
      const header = screen.getByRole("banner");
      const span = header.querySelector("span");
      expect(span?.textContent).not.toBe("");
    });
  });
});

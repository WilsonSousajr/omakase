import { describe, it, expect, vi, beforeEach } from "vitest";
import { screen, fireEvent } from "@testing-library/react";
import { renderWithProviders } from "@/test/utils";
import { useUIStore } from "@/stores/uiStore";
import Sidebar from "../Sidebar";

vi.mock("next/link", () => ({
  default: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>
      {children}
    </a>
  ),
}));

describe("Sidebar", () => {
  beforeEach(() => {
    useUIStore.setState({ sidebarOpen: true, modalOpen: null });
  });

  it("renders Plan and Focus nav links", () => {
    renderWithProviders(<Sidebar />);

    expect(screen.getByText("Plan")).toBeInTheDocument();
    expect(screen.getByText("Focus")).toBeInTheDocument();
  });

  it("shows Omakase text when sidebar is open", () => {
    useUIStore.setState({ sidebarOpen: true });
    renderWithProviders(<Sidebar />);

    expect(screen.getByText("Omakase")).toBeInTheDocument();
  });

  it("hides Omakase text when sidebar is closed", () => {
    useUIStore.setState({ sidebarOpen: false });
    renderWithProviders(<Sidebar />);

    expect(screen.queryByText("Omakase")).not.toBeInTheDocument();
  });

  it("toggle button changes sidebarOpen state", () => {
    useUIStore.setState({ sidebarOpen: true });
    renderWithProviders(<Sidebar />);

    const toggleButton = screen.getByRole("button");
    fireEvent.click(toggleButton);

    expect(useUIStore.getState().sidebarOpen).toBe(false);
  });

  it("active link has active styling when pathname matches", () => {
    // setup.ts mocks usePathname to return "/plan"
    useUIStore.setState({ sidebarOpen: true });
    renderWithProviders(<Sidebar />);

    const planLink = screen.getByText("Plan").closest("a");
    expect(planLink).toHaveClass("bg-[var(--color-surface-active)]");
    expect(planLink).toHaveClass("text-[var(--color-text-primary)]");

    const focusLink = screen.getByText("Focus").closest("a");
    expect(focusLink).not.toHaveClass("bg-[var(--color-surface-active)]");
    expect(focusLink).toHaveClass("text-[var(--color-text-muted)]");
  });
});

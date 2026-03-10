import { describe, it, expect, vi, beforeEach } from "vitest";
import { screen, fireEvent } from "@testing-library/react";
import { renderWithProviders } from "@/test/utils";
import { createMockUser } from "@/test/handlers";
import { useAuthStore } from "@/stores/authStore";
import { useUIStore } from "@/stores/uiStore";
import Sidebar from "../Sidebar";

vi.mock("next/link", () => ({
  default: ({ children, href, ...props }: { children: React.ReactNode; href: string; className?: string }) => (
    <a href={href} {...props}>
      {children}
    </a>
  ),
}));

describe("Sidebar", () => {
  beforeEach(() => {
    useUIStore.setState({ sidebarOpen: true, modalOpen: null });
    useAuthStore.setState({ user: createMockUser(), isAuthenticated: true });
  });

  it("renders Plan, Focus, and Projects nav links", () => {
    renderWithProviders(<Sidebar />);

    expect(screen.getByText("Plan")).toBeInTheDocument();
    expect(screen.getByText("Focus")).toBeInTheDocument();
    expect(screen.getByText("Projects")).toBeInTheDocument();
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

    const buttons = screen.getAllByRole("button");
    const toggleButton = buttons[0]; // Sidebar collapse button (first button)
    fireEvent.click(toggleButton);

    expect(useUIStore.getState().sidebarOpen).toBe(false);
  });

  it("shows user avatar and username when sidebar is open", () => {
    useUIStore.setState({ sidebarOpen: true });
    renderWithProviders(<Sidebar />);
    expect(screen.getByText("testuser")).toBeInTheDocument();
    expect(screen.getByText("TE")).toBeInTheDocument();
  });

  it("shows only user avatar when sidebar is collapsed", () => {
    useUIStore.setState({ sidebarOpen: false });
    renderWithProviders(<Sidebar />);
    expect(screen.getByText("TE")).toBeInTheDocument();
    expect(screen.queryByText("testuser")).not.toBeInTheDocument();
  });

  it("user section links to settings", () => {
    renderWithProviders(<Sidebar />);
    const settingsLink = screen.getByText("testuser").closest("a");
    expect(settingsLink).toHaveAttribute("href", "/settings");
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

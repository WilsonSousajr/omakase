import { screen } from "@testing-library/react";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";

import { useAuthStore } from "@/stores/authStore";
import { createMockUser, handlers } from "@/test/handlers";
import { renderWithProviders } from "@/test/utils";
import SettingsPage from "../page";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe("SettingsPage", () => {
  const mockUser = createMockUser({
    first_name: "John",
    last_name: "Doe",
    email: "john@example.com",
    avatar_color: "#ff5733",
  });

  beforeEach(() => {
    useAuthStore.setState({
      user: mockUser,
      tokens: { access: "mock-access", refresh: "mock-refresh" },
      isAuthenticated: true,
    });
  });

  afterEach(() => {
    useAuthStore.setState({
      user: null,
      tokens: null,
      isAuthenticated: false,
    });
  });

  it("renders settings heading", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByText("Settings")).toBeInTheDocument();
  });

  it("renders profile form with current user data", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByDisplayValue("John")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Doe")).toBeInTheDocument();
    expect(screen.getByDisplayValue("john@example.com")).toBeInTheDocument();
  });

  it("renders username as read-only text", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByText("testuser")).toBeInTheDocument();
  });

  it("renders avatar with initials", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByText("JD")).toBeInTheDocument();
  });

  it("renders password form", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByPlaceholderText("Current password")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("New password")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Confirm new password")).toBeInTheDocument();
  });

  it("renders save button", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByText("Save")).toBeInTheDocument();
  });

  it("renders change password button", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByRole("button", { name: "Change Password" })).toBeInTheDocument();
  });

  it("renders logout button", () => {
    renderWithProviders(<SettingsPage />);
    expect(screen.getByText("Log out")).toBeInTheDocument();
  });

  it("returns null when no user", () => {
    useAuthStore.setState({ user: null });
    const { container } = renderWithProviders(<SettingsPage />);
    expect(container.innerHTML).toBe("");
  });
});

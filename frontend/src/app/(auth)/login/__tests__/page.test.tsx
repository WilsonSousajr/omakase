import { screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { renderWithProviders } from "@/test/utils";

// Override the global GoogleLogin mock to render a visible button
vi.mock("@react-oauth/google", () => ({
  GoogleOAuthProvider: ({ children }: { children: React.ReactNode }) => children,
  GoogleLogin: () => <button data-testid="google-login-button">Sign in with Google</button>,
}));

// Must import after mocks
import LoginPage from "../page";

describe("LoginPage", () => {
  it("renders app name", () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByText("Omakase")).toBeInTheDocument();
  });

  it("renders sign-in message", () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByText("Sign in with Google")).toBeInTheDocument();
  });

  it("renders Google login button", () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByTestId("google-login-button")).toBeInTheDocument();
  });

  it("does not render username or password inputs", () => {
    renderWithProviders(<LoginPage />);
    expect(screen.queryByLabelText(/username/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/password/i)).not.toBeInTheDocument();
  });
});

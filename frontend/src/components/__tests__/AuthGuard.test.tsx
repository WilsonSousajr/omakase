import { QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

import { useAuthStore } from "@/stores/authStore";
import { createTestQueryClient } from "@/test/utils";
import { handlers } from "@/test/handlers";
import AuthGuard from "../AuthGuard";

const server = setupServer(...handlers);

const mockReplace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: mockReplace,
    back: vi.fn(),
    prefetch: vi.fn(),
  }),
  usePathname: () => "/plan",
  useSearchParams: () => new URLSearchParams(),
}));

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = createTestQueryClient();
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
  );
}

describe("AuthGuard", () => {
  beforeEach(() => {
    mockReplace.mockClear();
  });

  afterEach(() => {
    useAuthStore.setState({
      user: null,
      tokens: null,
      isAuthenticated: false,
    });
  });

  it("redirects to /login when unauthenticated", async () => {
    useAuthStore.setState({ isAuthenticated: false, tokens: null });
    renderWithProviders(
      <AuthGuard>
        <div>Protected Content</div>
      </AuthGuard>
    );
    await waitFor(() => {
      expect(mockReplace).toHaveBeenCalledWith("/login");
    });
    expect(screen.queryByText("Protected Content")).toBeNull();
  });

  it("shows children when authenticated", async () => {
    useAuthStore.setState({
      isAuthenticated: true,
      tokens: { access: "mock-access", refresh: "mock-refresh" },
    });
    renderWithProviders(
      <AuthGuard>
        <div>Protected Content</div>
      </AuthGuard>
    );
    await waitFor(() => {
      expect(screen.getByText("Protected Content")).toBeInTheDocument();
    });
  });

  it("shows loading state while fetching user", () => {
    useAuthStore.setState({
      isAuthenticated: true,
      user: null,
      tokens: { access: "mock-access", refresh: "mock-refresh" },
    });
    renderWithProviders(
      <AuthGuard>
        <div>Protected Content</div>
      </AuthGuard>
    );
    expect(screen.getByText("Loading...")).toBeInTheDocument();
  });
});

import { QueryClientProvider } from "@tanstack/react-query";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import type { ReactNode } from "react";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";

import { createTestQueryClient } from "@/test/utils";
import { useAuthStore } from "@/stores/authStore";
import { handlers } from "@/test/handlers";
import { useChangePassword, useMe, useUpdateProfile } from "../useAuth";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

describe("useMe", () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: null,
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

  it("fetches current user when authenticated", async () => {
    const { result } = renderHook(() => useMe(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.username).toBe("testuser");
  });

  it("does not fetch when unauthenticated", () => {
    useAuthStore.setState({ isAuthenticated: false, tokens: null });
    const { result } = renderHook(() => useMe(), { wrapper });
    expect(result.current.fetchStatus).toBe("idle");
  });
});

describe("useUpdateProfile", () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: null,
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

  it("sends PATCH and updates store", async () => {
    const { result } = renderHook(() => useUpdateProfile(), { wrapper });
    result.current.mutate({ first_name: "John", last_name: "Doe" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    const user = useAuthStore.getState().user;
    expect(user).not.toBeNull();
    expect(user?.first_name).toBe("John");
  });
});

describe("useChangePassword", () => {
  beforeEach(() => {
    useAuthStore.setState({
      user: null,
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

  it("sends POST and returns success", async () => {
    const { result } = renderHook(() => useChangePassword(), { wrapper });
    result.current.mutate({
      old_password: "testpass123",
      new_password: "newpass12345",
      new_password_confirm: "newpass12345",
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.detail).toBe("Password changed successfully.");
  });
});

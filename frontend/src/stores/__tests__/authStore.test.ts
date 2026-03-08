import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { useAuthStore } from "../authStore";

// Provide a minimal localStorage mock for store tests
const store: Record<string, string> = {};
vi.stubGlobal("localStorage", {
  getItem: (key: string) => store[key] ?? null,
  setItem: (key: string, value: string) => { store[key] = value; },
  removeItem: (key: string) => { delete store[key]; },
  clear: () => { Object.keys(store).forEach((k) => delete store[k]); },
});

describe("authStore", () => {
  beforeEach(() => {
    Object.keys(store).forEach((k) => delete store[k]);
    useAuthStore.setState({
      user: null,
      tokens: null,
      isAuthenticated: false,
    });
  });

  afterEach(() => {
    Object.keys(store).forEach((k) => delete store[k]);
  });

  it("starts unauthenticated", () => {
    const state = useAuthStore.getState();
    expect(state.user).toBeNull();
    expect(state.tokens).toBeNull();
    expect(state.isAuthenticated).toBe(false);
  });

  it("setAuth stores user and tokens", () => {
    const user = { id: 1, username: "test", email: "t@e.com", first_name: "", last_name: "", avatar_color: "#a3a3a3", date_joined: "2025-01-01" };
    const tokens = { access: "acc", refresh: "ref" };

    useAuthStore.getState().setAuth(user, tokens);

    const state = useAuthStore.getState();
    expect(state.user).toEqual(user);
    expect(state.tokens).toEqual(tokens);
    expect(state.isAuthenticated).toBe(true);
    expect(store["auth_tokens"]).toBe(JSON.stringify(tokens));
  });

  it("setTokens updates tokens and keeps authenticated", () => {
    const tokens = { access: "new-acc", refresh: "new-ref" };

    useAuthStore.getState().setTokens(tokens);

    const state = useAuthStore.getState();
    expect(state.tokens).toEqual(tokens);
    expect(state.isAuthenticated).toBe(true);
  });

  it("setUser updates user without changing auth state", () => {
    const user = { id: 1, username: "test", email: "t@e.com", first_name: "", last_name: "", avatar_color: "#a3a3a3", date_joined: "2025-01-01" };

    useAuthStore.getState().setUser(user);

    expect(useAuthStore.getState().user).toEqual(user);
  });

  it("logout clears everything", () => {
    const user = { id: 1, username: "test", email: "t@e.com", first_name: "", last_name: "", avatar_color: "#a3a3a3", date_joined: "2025-01-01" };
    const tokens = { access: "acc", refresh: "ref" };

    useAuthStore.getState().setAuth(user, tokens);
    useAuthStore.getState().logout();

    const state = useAuthStore.getState();
    expect(state.user).toBeNull();
    expect(state.tokens).toBeNull();
    expect(state.isAuthenticated).toBe(false);
    expect(store["auth_tokens"]).toBeUndefined();
  });
});

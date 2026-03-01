import { create } from "zustand";

import type { AuthTokens, User } from "@/types/auth";

interface AuthState {
  user: User | null;
  tokens: AuthTokens | null;
  isAuthenticated: boolean;
  setAuth: (user: User, tokens: AuthTokens) => void;
  setTokens: (tokens: AuthTokens) => void;
  setUser: (user: User) => void;
  logout: () => void;
}

function loadTokens(): AuthTokens | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem("auth_tokens");
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function saveTokens(tokens: AuthTokens | null) {
  if (typeof window === "undefined") return;
  if (tokens) {
    localStorage.setItem("auth_tokens", JSON.stringify(tokens));
  } else {
    localStorage.removeItem("auth_tokens");
  }
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  tokens: loadTokens(),
  isAuthenticated: !!loadTokens(),
  setAuth: (user, tokens) => {
    saveTokens(tokens);
    set({ user, tokens, isAuthenticated: true });
  },
  setTokens: (tokens) => {
    saveTokens(tokens);
    set({ tokens, isAuthenticated: true });
  },
  setUser: (user) => set({ user }),
  logout: () => {
    saveTokens(null);
    set({ user: null, tokens: null, isAuthenticated: false });
  },
}));

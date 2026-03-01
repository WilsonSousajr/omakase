"use client";

import Link from "next/link";
import { useState } from "react";

import { useLogin } from "@/hooks/useAuth";

export default function LoginPage() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const login = useLogin();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    login.mutate({ username, password });
  }

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">
          Omakase
        </h1>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          Sign in to your account
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Username
          </label>
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
            autoFocus
            className="mt-1 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none focus:border-[var(--color-border-hover)]"
            placeholder="Enter your username"
          />
        </div>

        <div>
          <label className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Password
          </label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            className="mt-1 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none focus:border-[var(--color-border-hover)]"
            placeholder="Enter your password"
          />
        </div>

        {login.error && (
          <p className="text-sm text-red-400">
            Invalid username or password.
          </p>
        )}

        <button
          type="submit"
          disabled={login.isPending}
          className="w-full rounded-xl bg-[var(--color-button-primary)] py-2 text-sm font-medium text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {login.isPending ? "Signing in..." : "Sign in"}
        </button>
      </form>

      <p className="text-center text-sm text-[var(--color-text-muted)]">
        Don&apos;t have an account?{" "}
        <Link
          href="/register"
          className="text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
        >
          Sign up
        </Link>
      </p>
    </div>
  );
}

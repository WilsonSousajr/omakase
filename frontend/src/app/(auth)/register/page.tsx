"use client";

import axios from "axios";
import Link from "next/link";
import { useState } from "react";

import { useRegister } from "@/hooks/useAuth";

export default function RegisterPage() {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const register = useRegister();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    register.mutate({
      username,
      email,
      password,
      password_confirm: passwordConfirm,
    });
  }

  function getErrorMessage(): string | null {
    if (!register.error) return null;
    if (axios.isAxiosError(register.error) && register.error.response?.data) {
      const data = register.error.response.data;
      const firstKey = Object.keys(data)[0];
      if (firstKey) {
        const msg = Array.isArray(data[firstKey])
          ? data[firstKey][0]
          : data[firstKey];
        return String(msg);
      }
    }
    return "Registration failed. Please try again.";
  }

  const errorMessage = getErrorMessage();

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">
          Omakase
        </h1>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          Create your account
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
            placeholder="Choose a username"
          />
        </div>

        <div>
          <label className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Email
          </label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            className="mt-1 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none focus:border-[var(--color-border-hover)]"
            placeholder="you@example.com"
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
            minLength={8}
            className="mt-1 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none focus:border-[var(--color-border-hover)]"
            placeholder="At least 8 characters"
          />
        </div>

        <div>
          <label className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Confirm password
          </label>
          <input
            type="password"
            value={passwordConfirm}
            onChange={(e) => setPasswordConfirm(e.target.value)}
            required
            minLength={8}
            className="mt-1 w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none focus:border-[var(--color-border-hover)]"
            placeholder="Repeat your password"
          />
        </div>

        {errorMessage && (
          <p className="text-sm text-red-400">{errorMessage}</p>
        )}

        <button
          type="submit"
          disabled={register.isPending}
          className="w-full rounded-xl bg-[var(--color-button-primary)] py-2 text-sm font-medium text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {register.isPending ? "Creating account..." : "Create account"}
        </button>
      </form>

      <p className="text-center text-sm text-[var(--color-text-muted)]">
        Already have an account?{" "}
        <Link
          href="/login"
          className="text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
        >
          Sign in
        </Link>
      </p>
    </div>
  );
}

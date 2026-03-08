"use client";

import { useTheme } from "next-themes";
import { Monitor, Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";

const THEME_CYCLE = { system: "light", light: "dark", dark: "system" } as const;

export default function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const Icon = !mounted
    ? Monitor
    : theme === "light"
      ? Sun
      : theme === "dark"
        ? Moon
        : Monitor;

  return (
    <button
      aria-label="Toggle theme"
      onClick={() =>
        setTheme(THEME_CYCLE[(theme as keyof typeof THEME_CYCLE) ?? "system"])
      }
      className="rounded-lg p-1.5 text-[var(--color-text-faint)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
    >
      <Icon className="h-4 w-4" />
    </button>
  );
}

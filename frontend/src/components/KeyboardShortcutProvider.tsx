"use client";

import { useKeyboardShortcuts } from "@/hooks/useKeyboardShortcuts";

export default function KeyboardShortcutProvider({ children }: { children: React.ReactNode }) {
  useKeyboardShortcuts();
  return <>{children}</>;
}

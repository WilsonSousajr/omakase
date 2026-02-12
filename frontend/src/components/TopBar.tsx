"use client";

import { format } from "date-fns";
import { Plus } from "lucide-react";
import { useUIStore } from "@/stores/uiStore";

export default function TopBar() {
  const { openModal } = useUIStore();

  return (
    <header className="flex h-12 items-center justify-between bg-[var(--color-bg)] px-4">
      <span className="text-sm text-[var(--color-text-secondary)]">
        {format(new Date(), "EEEE, MMMM d")}
      </span>
      <button
        onClick={() => openModal("task-form")}
        className="flex items-center gap-1.5 rounded-xl bg-[#e5e5e5] px-3 py-1.5 text-xs font-medium text-[#0a0a0a] transition-colors hover:bg-[#d4d4d4]"
      >
        <Plus className="h-3.5 w-3.5" />
        New Task
      </button>
    </header>
  );
}

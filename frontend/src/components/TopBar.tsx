"use client";

import { format } from "date-fns";
import { Plus } from "lucide-react";
import { useUIStore } from "@/stores/uiStore";

export default function TopBar() {
  const { openModal } = useUIStore();

  return (
    <header className="flex h-12 items-center justify-between border-b border-zinc-800 bg-zinc-950 px-4">
      <span className="text-sm text-zinc-400">
        {format(new Date(), "EEEE, MMMM d")}
      </span>
      <button
        onClick={() => openModal("task-form")}
        className="flex items-center gap-1.5 rounded-md bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-indigo-500"
      >
        <Plus className="h-3.5 w-3.5" />
        New Task
      </button>
    </header>
  );
}

"use client";

import KanbanBoard from "@/components/kanban/KanbanBoard";
import ActiveTaskPanel from "@/components/focus/ActiveTaskPanel";

export default function FocusPage() {
  return (
    <div className="flex h-full">
      <div className="flex-1 border-r border-[var(--color-border)]">
        <KanbanBoard />
      </div>
      <div className="w-96 shrink-0">
        <ActiveTaskPanel />
      </div>
    </div>
  );
}

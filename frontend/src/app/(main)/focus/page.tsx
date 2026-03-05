"use client";

import KanbanBoard from "@/components/kanban/KanbanBoard";
import TodayStudyBlocks from "@/components/kanban/TodayStudyBlocks";
import ActiveTaskPanel from "@/components/focus/ActiveTaskPanel";

export default function FocusPage() {
  return (
    <div className="flex h-full">
      <div className="flex flex-1 flex-col border-r border-[var(--color-border)]">
        <div className="flex-1 overflow-auto">
          <KanbanBoard />
        </div>
        <TodayStudyBlocks />
      </div>
      <div className="w-96 shrink-0">
        <ActiveTaskPanel />
      </div>
    </div>
  );
}

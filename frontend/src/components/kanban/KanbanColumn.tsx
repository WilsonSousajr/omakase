"use client";

import { useDroppable } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { cn } from "@/lib/utils";
import type { Task } from "@/types/task";
import type { KanbanStatus } from "@/lib/constants";
import KanbanCard from "./KanbanCard";

interface KanbanColumnProps {
  status: KanbanStatus;
  label: string;
  tasks: Task[];
}

export default function KanbanColumn({ status, label, tasks }: KanbanColumnProps) {
  const { setNodeRef, isOver } = useDroppable({
    id: `column-${status}`,
    data: { type: "column", status },
  });

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "flex flex-1 flex-col rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)]/50 transition-all duration-300",
        isOver && "border-[var(--color-border-hover)] bg-white/5"
      )}
    >
      <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-4 py-3">
        <h3 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{label}</h3>
        <span className="rounded-lg bg-[var(--color-surface)] px-2 py-0.5 text-[10px] text-[var(--color-text-muted)]">
          {tasks.length}
        </span>
      </div>

      <div className="flex-1 space-y-3 overflow-auto p-4">
        <SortableContext
          items={tasks.map((t) => t.id)}
          strategy={verticalListSortingStrategy}
        >
          {tasks.map((task) => (
            <KanbanCard key={task.id} task={task} />
          ))}
        </SortableContext>

        {tasks.length === 0 && (
          <div className="flex items-center justify-center py-8 text-xs text-[var(--color-text-faint)]">
            Drop tasks here
          </div>
        )}
      </div>
    </div>
  );
}

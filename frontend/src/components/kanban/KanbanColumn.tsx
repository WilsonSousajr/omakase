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
        "flex flex-1 flex-col rounded-xl border border-zinc-800 bg-zinc-950/50 transition-colors",
        isOver && "border-indigo-500/30 bg-indigo-500/5"
      )}
    >
      <div className="flex items-center gap-2 border-b border-zinc-800 px-4 py-3">
        <h3 className="text-sm font-medium text-zinc-300">{label}</h3>
        <span className="rounded-full bg-zinc-800 px-2 py-0.5 text-[10px] text-zinc-400">
          {tasks.length}
        </span>
      </div>

      <div className="flex-1 space-y-2 overflow-auto p-3">
        <SortableContext
          items={tasks.map((t) => t.id)}
          strategy={verticalListSortingStrategy}
        >
          {tasks.map((task) => (
            <KanbanCard key={task.id} task={task} />
          ))}
        </SortableContext>

        {tasks.length === 0 && (
          <div className="flex items-center justify-center py-8 text-xs text-zinc-600">
            Drop tasks here
          </div>
        )}
      </div>
    </div>
  );
}

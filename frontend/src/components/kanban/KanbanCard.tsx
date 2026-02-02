"use client";

import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { PRIORITIES } from "@/lib/constants";
import { cn } from "@/lib/utils";
import type { Task } from "@/types/task";
import { GripVertical } from "lucide-react";
import { useUIStore } from "@/stores/uiStore";

interface KanbanCardProps {
  task: Task;
}

export default function KanbanCard({ task }: KanbanCardProps) {
  const { activeTaskId, setActiveTaskId } = useUIStore();
  const priority = PRIORITIES.find((p) => p.value === task.priority);
  const isActive = activeTaskId === task.id;

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({
    id: task.id,
    data: { type: "kanban-card", task },
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      onClick={() => setActiveTaskId(task.id)}
      className={cn(
        "group cursor-pointer rounded-lg border bg-zinc-900 p-3 transition-colors",
        isActive
          ? "border-indigo-500/50 ring-1 ring-indigo-500/20"
          : "border-zinc-800 hover:border-zinc-700"
      )}
    >
      <div className="flex items-start gap-2">
        <button
          className="mt-0.5 cursor-grab text-zinc-600 hover:text-zinc-400 active:cursor-grabbing"
          {...listeners}
          {...attributes}
        >
          <GripVertical className="h-4 w-4" />
        </button>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className={cn(
              "truncate text-sm font-medium text-zinc-200",
              task.is_completed && "line-through opacity-60"
            )}>
              {task.title}
            </span>
          </div>

          <div className="mt-1.5 flex items-center gap-1.5">
            {priority && (
              <span
                className="rounded px-1.5 py-0.5 text-[10px] font-medium"
                style={{
                  backgroundColor: priority.color + "20",
                  color: priority.color,
                }}
              >
                {priority.label}
              </span>
            )}
            {task.tags.map((tag) => (
              <span
                key={tag.id}
                className="rounded px-1.5 py-0.5 text-[10px]"
                style={{
                  backgroundColor: tag.color + "20",
                  color: tag.color,
                }}
              >
                {tag.name}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

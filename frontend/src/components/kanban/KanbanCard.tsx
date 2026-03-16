"use client";

import { memo } from "react";
import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { PRIORITIES } from "@/lib/constants";
import { cn } from "@/lib/utils";
import type { Task } from "@/types/task";
import { GripVertical } from "lucide-react";
import { useTranslations } from "next-intl";
import { useUIStore } from "@/stores/uiStore";

interface KanbanCardProps {
  task: Task;
}

function KanbanCard({ task }: KanbanCardProps) {
  const tc = useTranslations("constants");
  const activeTaskId = useUIStore((s) => s.activeTaskId);
  const setActiveTaskId = useUIStore((s) => s.setActiveTaskId);
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
        "group cursor-grab rounded-2xl border bg-[var(--color-surface)] p-4 transition-all duration-300 active:cursor-grabbing",
        isActive
          ? "border-[var(--color-ring-overlay)] ring-1 ring-[var(--color-ring-overlay)]"
          : "border-[var(--color-border)] hover:border-[var(--color-border-hover)]"
      )}
      {...listeners}
      {...attributes}
    >
      <div className="flex items-start gap-2">
        <div className="mt-0.5 text-[var(--color-text-faint)] group-hover:text-[var(--color-text-muted)]">
          <GripVertical className="h-4 w-4" />
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className={cn(
              "truncate text-sm font-medium text-[var(--color-text-primary)]",
              task.is_completed && "line-through opacity-60"
            )}>
              {task.title}
            </span>
          </div>

          <div className="mt-1.5 flex items-center gap-1.5">
            {priority && (
              <span
                className="rounded-lg px-1.5 py-0.5 text-[10px] font-medium"
                style={{
                  backgroundColor: priority.color + "20",
                  color: priority.color,
                }}
              >
                {tc(`priorities.${priority.value}`)}
              </span>
            )}
            {task.tags.map((tag) => (
              <span
                key={tag.id}
                className="rounded-lg px-1.5 py-0.5 text-[10px]"
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

export default memo(KanbanCard);

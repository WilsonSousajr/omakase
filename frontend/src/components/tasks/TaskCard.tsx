"use client";

import { cn } from "@/lib/utils";
import { PRIORITIES } from "@/lib/constants";
import type { Task } from "@/types/task";
import { GripVertical, Pencil, Trash2, Calendar } from "lucide-react";
import { format } from "date-fns";

interface TaskCardProps {
  task: Task;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
  onToggleComplete: (id: string, isCompleted: boolean) => void;
}

export default function TaskCard({ task, onEdit, onDelete, onToggleComplete }: TaskCardProps) {
  const priority = PRIORITIES.find((p) => p.value === task.priority);

  return (
    <div
      className={cn(
        "group flex items-start gap-2 rounded-lg border border-zinc-800 bg-zinc-900 p-3 transition-colors hover:border-zinc-700"
      )}
    >
      {/* Checkbox */}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onToggleComplete(task.id, !task.is_completed);
        }}
        className="mt-0.5 shrink-0"
      >
        <div className={cn(
          "h-4 w-4 rounded border transition-all",
          task.is_completed
            ? "bg-blue-500 border-blue-500"
            : "border-zinc-600 hover:border-zinc-500"
        )}>
          {task.is_completed && (
            <svg className="h-full w-full text-white" viewBox="0 0 16 16">
              <path fill="currentColor" d="M13 4L6 11L3 8" strokeWidth="2" stroke="currentColor" />
            </svg>
          )}
        </div>
      </button>

      <div className="mt-0.5 text-zinc-600">
        <GripVertical className="h-4 w-4" />
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className={cn(
            "truncate text-sm font-medium text-zinc-200",
            task.is_completed && "line-through opacity-60"
          )}>
            {task.title}
          </span>
          {priority && (
            <span
              className="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium"
              style={{
                backgroundColor: priority.color + "20",
                color: priority.color,
              }}
            >
              {priority.label}
            </span>
          )}
        </div>

        {task.description && (
          <p className="mt-0.5 truncate text-xs text-zinc-500">
            {task.description}
          </p>
        )}

        <div className="mt-1.5 flex items-center gap-2">
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
          {task.scheduled_date && (
            <span className="flex items-center gap-1 text-[10px] text-zinc-500">
              <Calendar className="h-3 w-3" />
              {format(new Date(task.scheduled_date + "T00:00:00"), "MMM d")}
            </span>
          )}
        </div>
      </div>

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={() => onEdit(task)}
          onPointerDown={(e) => e.stopPropagation()}
          className="rounded p-1 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={() => onDelete(task.id)}
          onPointerDown={(e) => e.stopPropagation()}
          className="rounded p-1 text-zinc-500 hover:bg-red-900/50 hover:text-red-400"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

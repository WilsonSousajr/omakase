"use client";

import { Pencil, Trash2, ListTodo, CalendarDays } from "lucide-react";
import { format } from "date-fns";
import type { Project } from "@/types/project";

interface ProjectCardProps {
  project: Project;
  onEdit: (project: Project) => void;
  onDelete: (id: string) => void;
}

export default function ProjectCard({ project, onEdit, onDelete }: ProjectCardProps) {
  return (
    <div className="group flex items-start gap-3 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-all duration-300 hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]">
      <div
        className="mt-1 h-3 w-3 shrink-0 rounded-full"
        style={{ backgroundColor: project.color }}
      />

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm font-medium text-[var(--color-text-primary)]">
            {project.name}
          </span>
        </div>

        {project.description && (
          <p className="mt-0.5 truncate text-xs text-[var(--color-text-muted)]">
            {project.description}
          </p>
        )}

        <div className="mt-1.5 flex items-center gap-3">
          <span className="flex items-center gap-1 text-[10px] text-[var(--color-text-muted)]">
            <ListTodo className="h-3 w-3" />
            {project.task_count} {project.task_count === 1 ? "task" : "tasks"}
          </span>
          {project.due_date && (
            <span className="flex items-center gap-1 text-[10px] text-[var(--color-text-muted)]">
              <CalendarDays className="h-3 w-3" />
              {format(new Date(project.due_date + "T00:00:00"), "MMM d, yyyy")}
            </span>
          )}
        </div>
      </div>

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={() => onEdit(project)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={() => onDelete(project.id)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[#ef4444]/10 hover:text-[#ef4444]"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

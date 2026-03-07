"use client";

import { Pencil, Trash2, BookOpen, CalendarDays } from "lucide-react";
import { format } from "date-fns";
import type { Semester } from "@/types/semester";

interface SemesterCardProps {
  semester: Semester;
  onEdit: (semester: Semester) => void;
  onDelete: (id: string) => void;
}

export default function SemesterCard({ semester, onEdit, onDelete }: SemesterCardProps) {
  return (
    <div className="group flex items-start gap-3 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-all duration-300 hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]">
      <div className="min-w-0 flex-1">
        <span className="truncate text-sm font-medium text-[var(--color-text-primary)]">
          {semester.name}
        </span>

        {semester.institution && (
          <p className="mt-0.5 truncate text-xs text-[var(--color-text-muted)]">
            {semester.institution}
          </p>
        )}

        <div className="mt-1.5 flex items-center gap-3">
          <span className="flex items-center gap-1 text-[10px] text-[var(--color-text-muted)]">
            <BookOpen className="h-3 w-3" />
            {semester.discipline_count} {semester.discipline_count === 1 ? "discipline" : "disciplines"}
          </span>
          <span className="flex items-center gap-1 text-[10px] text-[var(--color-text-muted)]">
            <CalendarDays className="h-3 w-3" />
            {format(new Date(semester.start_date + "T00:00:00"), "MMM d")} – {format(new Date(semester.end_date + "T00:00:00"), "MMM d, yyyy")}
          </span>
        </div>
      </div>

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={() => onEdit(semester)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={() => onDelete(semester.id)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[#ef4444]/10 hover:text-[#ef4444]"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

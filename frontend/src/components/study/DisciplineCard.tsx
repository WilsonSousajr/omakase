"use client";

import { Pencil, Trash2, BookOpen, User } from "lucide-react";
import type { Discipline } from "@/types/discipline";

interface DisciplineCardProps {
  discipline: Discipline;
  onEdit: (discipline: Discipline) => void;
  onDelete: (id: string) => void;
  onClick?: (discipline: Discipline) => void;
}

export default function DisciplineCard({ discipline, onEdit, onDelete, onClick }: DisciplineCardProps) {
  return (
    <div
      className="group flex items-start gap-3 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-all duration-300 hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]"
      role={onClick ? "button" : undefined}
      onClick={onClick ? () => onClick(discipline) : undefined}
    >
      <div
        className="mt-1 h-3 w-3 shrink-0 rounded-full"
        style={{ backgroundColor: discipline.color }}
      />

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm font-medium text-[var(--color-text-primary)]">
            {discipline.name}
          </span>
          {discipline.code && (
            <span className="shrink-0 text-[10px] text-[var(--color-text-faint)]">
              {discipline.code}
            </span>
          )}
        </div>

        {discipline.professor && (
          <p className="mt-0.5 flex items-center gap-1 truncate text-xs text-[var(--color-text-muted)]">
            <User className="h-3 w-3 shrink-0" />
            {discipline.professor}
          </p>
        )}

        <div className="mt-1.5 flex items-center gap-3">
          <span className="flex items-center gap-1 text-[10px] text-[var(--color-text-muted)]">
            <BookOpen className="h-3 w-3" />
            {discipline.study_block_count} {discipline.study_block_count === 1 ? "block" : "blocks"}
          </span>
          {discipline.credits && (
            <span className="text-[10px] text-[var(--color-text-muted)]">
              {discipline.credits} credits
            </span>
          )}
        </div>
      </div>

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onClick={(e) => { e.stopPropagation(); onEdit(discipline); }}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={(e) => { e.stopPropagation(); onDelete(discipline.id); }}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[#ef4444]/10 hover:text-[#ef4444]"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}

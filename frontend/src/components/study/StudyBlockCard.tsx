"use client";

import React from "react";
import { Pencil, Trash2, CalendarDays } from "lucide-react";
import { format } from "date-fns";
import { PRIORITIES, STUDY_BLOCK_TYPES } from "@/lib/constants";
import type { StudyBlock } from "@/types/studyblock";
import type { Discipline } from "@/types/discipline";
import DisciplineBadge from "./DisciplineBadge";

interface StudyBlockCardProps {
  block: StudyBlock;
  disciplines?: Map<string, Discipline>;
  onEdit: (block: StudyBlock) => void;
  onDelete: (id: string) => void;
  onToggleComplete: (block: StudyBlock) => void;
}

const StudyBlockCard = React.memo(function StudyBlockCard({
  block,
  disciplines,
  onEdit,
  onDelete,
  onToggleComplete,
}: StudyBlockCardProps) {
  const priority = PRIORITIES.find((p) => p.value === block.priority);
  const blockType = STUDY_BLOCK_TYPES.find((t) => t.value === block.block_type);
  const discipline = disciplines?.get(block.discipline);

  return (
    <div className="group flex items-start gap-2.5 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 transition-all duration-300 hover:bg-[var(--color-surface-hover)] hover:border-[var(--color-border-hover)]">
      <button
        onClick={() => onToggleComplete(block)}
        className="mt-0.5 shrink-0"
      >
        <div
          className="flex h-4 w-4 items-center justify-center rounded border"
          style={{
            borderColor: block.is_completed ? (priority?.color || "#a3a3a3") : "var(--color-text-faint)",
            backgroundColor: block.is_completed ? (priority?.color || "#a3a3a3") : "transparent",
          }}
        >
          {block.is_completed && (
            <svg className="h-3 w-3 text-black" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
            </svg>
          )}
        </div>
      </button>

      <div className="min-w-0 flex-1">
        <span
          className={`text-sm font-medium text-[var(--color-text-primary)] ${
            block.is_completed ? "line-through opacity-60" : ""
          }`}
        >
          {block.title}
        </span>

        <div className="mt-1 flex flex-wrap items-center gap-1.5">
          {priority && (
            <span
              className="rounded-lg px-1.5 py-0.5 text-[10px]"
              style={{ backgroundColor: priority.color + "20", color: priority.color }}
            >
              {priority.label}
            </span>
          )}
          {blockType && (
            <span className="rounded-lg bg-[var(--color-surface-active)] px-1.5 py-0.5 text-[10px] text-[var(--color-text-secondary)]">
              {blockType.label}
            </span>
          )}
          {discipline && (
            <DisciplineBadge name={discipline.name} color={discipline.color} />
          )}
          {block.scheduled_date && (
            <span className="flex items-center gap-0.5 text-[10px] text-[var(--color-text-muted)]">
              <CalendarDays className="h-2.5 w-2.5" />
              {format(new Date(block.scheduled_date + "T00:00:00"), "MMM d")}
            </span>
          )}
        </div>
      </div>

      <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
        <button
          onPointerDown={(e) => e.stopPropagation()}
          onClick={() => onEdit(block)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
        >
          <Pencil className="h-3.5 w-3.5" />
        </button>
        <button
          onPointerDown={(e) => e.stopPropagation()}
          onClick={() => onDelete(block.id)}
          className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[#ef4444]/10 hover:text-[#ef4444]"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
});

export default StudyBlockCard;

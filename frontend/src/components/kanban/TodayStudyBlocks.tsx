"use client";

import { useMemo } from "react";
import { format } from "date-fns";
import { BookOpen } from "lucide-react";
import { useStudyBlocks, useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDisciplines } from "@/hooks/useDisciplines";
import { PRIORITIES, STUDY_BLOCK_TYPES } from "@/lib/constants";
import type { Discipline } from "@/types/discipline";

export default function TodayStudyBlocks() {
  const today = format(new Date(), "yyyy-MM-dd");
  const { data: studyBlocks = [] } = useStudyBlocks({ scheduled_date: today });
  const { data: disciplines = [] } = useDisciplines();
  const updateStudyBlock = useUpdateStudyBlock();

  const disciplineMap = useMemo(() => {
    const map = new Map<string, Discipline>();
    for (const d of disciplines) map.set(d.id, d);
    return map;
  }, [disciplines]);

  if (studyBlocks.length === 0) return null;

  return (
    <div className="border-t border-[var(--color-border)] p-4">
      <div className="mb-3 flex items-center gap-2">
        <BookOpen className="h-3.5 w-3.5 text-[var(--color-text-muted)]" />
        <h3 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          Today&apos;s Study Blocks
        </h3>
        <span className="rounded-lg bg-[var(--color-surface)] px-2 py-0.5 text-[10px] text-[var(--color-text-muted)]">
          {studyBlocks.length}
        </span>
      </div>
      <div className="space-y-2">
        {studyBlocks.map((block) => {
          const discipline = disciplineMap.get(block.discipline);
          const priority = PRIORITIES.find((p) => p.value === block.priority);
          const blockType = STUDY_BLOCK_TYPES.find((t) => t.value === block.block_type);

          return (
            <div
              key={block.id}
              className="flex items-center gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-2.5 transition-colors hover:bg-[var(--color-surface-hover)]"
            >
              <button
                onClick={() =>
                  updateStudyBlock.mutate({
                    id: block.id,
                    is_completed: !block.is_completed,
                  })
                }
                className="shrink-0"
              >
                <div
                  className="flex h-3.5 w-3.5 items-center justify-center rounded border"
                  style={{
                    borderColor: block.is_completed ? (priority?.color || "#a3a3a3") : "var(--color-text-faint)",
                    backgroundColor: block.is_completed ? (priority?.color || "#a3a3a3") : "transparent",
                  }}
                >
                  {block.is_completed && (
                    <svg className="h-2.5 w-2.5 text-black" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                  )}
                </div>
              </button>

              <div className="min-w-0 flex-1">
                <span
                  className={`text-xs font-medium text-[var(--color-text-primary)] ${
                    block.is_completed ? "line-through opacity-60" : ""
                  }`}
                >
                  {block.title}
                </span>
                <div className="mt-0.5 flex items-center gap-1.5">
                  {blockType && (
                    <span className="rounded-md bg-[var(--color-surface-active)] px-1 py-0.5 text-[9px] text-[var(--color-text-secondary)]">
                      {blockType.label}
                    </span>
                  )}
                  {discipline && (
                    <span
                      className="flex items-center gap-0.5 rounded-md px-1 py-0.5 text-[9px]"
                      style={{ backgroundColor: discipline.color + "20", color: discipline.color }}
                    >
                      <BookOpen className="h-2 w-2" />
                      {discipline.name}
                    </span>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

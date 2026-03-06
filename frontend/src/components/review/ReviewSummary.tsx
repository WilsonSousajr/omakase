"use client";

import { Check, Circle } from "lucide-react";
import type { ReviewSummary as ReviewSummaryType } from "@/types/dailyreview";

interface Props {
  summary: ReviewSummaryType;
  onNext: () => void;
}

export default function ReviewSummary({ summary, onNext }: Props) {
  const completionPct =
    summary.blocks_total > 0
      ? Math.round((summary.blocks_completed / summary.blocks_total) * 100)
      : 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          Today&apos;s Review
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">{summary.date}</p>
      </div>

      {/* Stats row */}
      <div className="flex gap-4">
        {[
          { label: "Hours focused", value: `${summary.hours_focused}h` },
          {
            label: "Blocks",
            value: `${summary.blocks_completed}/${summary.blocks_total}`,
          },
          { label: "Completion", value: `${completionPct}%` },
        ].map((stat) => (
          <div
            key={stat.label}
            className="flex-1 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-center"
          >
            <div className="text-xl font-semibold text-[var(--color-text-primary)]">
              {stat.value}
            </div>
            <div className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {stat.label}
            </div>
          </div>
        ))}
      </div>

      {/* Completed items */}
      {summary.completed_items.length > 0 && (
        <div>
          <h3 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Completed
          </h3>
          <div className="space-y-1.5">
            {summary.completed_items.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
              >
                <Check className="h-3.5 w-3.5 shrink-0 text-green-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {item.title}
                </span>
                {item.estimated_minutes && (
                  <span className="text-xs text-[var(--color-text-faint)]">
                    {item.actual_minutes}m / {item.estimated_minutes}m est.
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Incomplete items */}
      {(summary.incomplete_tasks.length > 0 ||
        summary.incomplete_study_blocks.length > 0) && (
        <div>
          <h3 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Incomplete
          </h3>
          <div className="space-y-1.5">
            {summary.incomplete_tasks.map((task) => (
              <div
                key={task.id}
                className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-2"
              >
                <Circle className="h-3.5 w-3.5 shrink-0 text-amber-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {task.title}
                </span>
              </div>
            ))}
            {summary.incomplete_study_blocks.map((sb) => (
              <div
                key={sb.id}
                className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-2"
              >
                <Circle className="h-3.5 w-3.5 shrink-0 text-amber-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {sb.title}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="flex justify-end pt-2">
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          Continue
        </button>
      </div>
    </div>
  );
}

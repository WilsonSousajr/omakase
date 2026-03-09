"use client";

import { memo, useState } from "react";
import { useTranslations } from "next-intl";
import { ChevronDown, Moon, Check, Circle } from "lucide-react";
import { useReviewSummary } from "@/hooks/useDailyReviews";
import { cn } from "@/lib/utils";
import type { DailyReview } from "@/types/dailyreview";

interface Props {
  review: DailyReview;
}

function ReviewHistoryCard({ review }: Props) {
  const t = useTranslations("review");
  const [expanded, setExpanded] = useState(false);
  const { data: summary, isLoading } = useReviewSummary(expanded ? review.date : "");

  const date = new Date(review.date + "T00:00:00");
  const formatted = date.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
  const year = date.getFullYear();

  const completionPct =
    summary && summary.blocks_total > 0
      ? Math.round((summary.blocks_completed / summary.blocks_total) * 100)
      : 0;

  return (
    <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] transition-colors hover:bg-[var(--color-surface-hover)]">
      {/* Compact view */}
      <button
        onClick={() => setExpanded((e) => !e)}
        className="flex w-full items-center gap-3 px-4 py-3 text-left"
      >
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-sm font-medium text-[var(--color-text-primary)]">
              {formatted}
            </span>
            <span className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]">
              {year}
            </span>
          </div>
          {review.win_of_the_day && (
            <p className="mt-0.5 line-clamp-1 text-xs text-[var(--color-text-muted)]">
              &ldquo;{review.win_of_the_day}&rdquo;
            </p>
          )}
        </div>

        {/* Rating dots */}
        {review.productivity_rating !== null && (
          <div className="flex items-center gap-1">
            {[1, 2, 3, 4, 5].map((n) => (
              <div
                key={n}
                className={cn(
                  "h-1.5 w-1.5 rounded-full",
                  n <= (review.productivity_rating ?? 0)
                    ? "bg-[var(--color-text-primary)]"
                    : "bg-[var(--color-text-faint)]"
                )}
              />
            ))}
          </div>
        )}

        {review.is_shutdown && (
          <Moon className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-muted)]" />
        )}

        <ChevronDown
          className={cn(
            "h-4 w-4 shrink-0 text-[var(--color-text-faint)] transition-transform",
            expanded && "rotate-180"
          )}
        />
      </button>

      {/* Expanded view */}
      {expanded && (
        <div className="border-t border-[var(--color-border)] px-4 py-3 space-y-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-4">
              <div className="h-5 w-5 animate-spin rounded-full border-2 border-[var(--color-text-faint)] border-t-[var(--color-text-primary)]" />
            </div>
          ) : summary ? (
            <>
              {/* Stats row */}
              <div className="flex gap-3">
                {[
                  { label: t("summary.hoursFocused"), value: `${summary.hours_focused}h` },
                  {
                    label: t("summary.blocksCompleted"),
                    value: `${summary.blocks_completed}/${summary.blocks_total}`,
                  },
                  { label: t("summary.completionRate"), value: `${completionPct}%` },
                ].map((stat) => (
                  <div
                    key={stat.label}
                    className="flex-1 rounded-xl bg-[var(--color-bg)] p-3 text-center"
                  >
                    <div className="text-base font-semibold text-[var(--color-text-primary)]">
                      {stat.value}
                    </div>
                    <div className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                      {stat.label}
                    </div>
                  </div>
                ))}
              </div>

              {/* Win */}
              {review.win_of_the_day && (
                <div>
                  <h4 className="mb-1 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {t("historySection.winOfTheDay")}
                  </h4>
                  <p className="text-sm text-[var(--color-text-secondary)]">
                    {review.win_of_the_day}
                  </p>
                </div>
              )}

              {/* Completed items */}
              {summary.completed_items.length > 0 && (
                <div>
                  <h4 className="mb-1.5 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {t("summary.completed")}
                  </h4>
                  <div className="space-y-1">
                    {summary.completed_items.map((item) => (
                      <div
                        key={item.id}
                        className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1.5"
                      >
                        <Check className="h-3.5 w-3.5 shrink-0 text-green-500" />
                        <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                          {item.title}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Incomplete items */}
              {(summary.incomplete_tasks.length > 0 ||
                summary.incomplete_study_blocks.length > 0) && (
                <div>
                  <h4 className="mb-1.5 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {t("summary.incomplete")}
                  </h4>
                  <div className="space-y-1">
                    {summary.incomplete_tasks.map((task) => (
                      <div
                        key={task.id}
                        className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-1.5"
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
                        className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-1.5"
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
            </>
          ) : null}
        </div>
      )}
    </div>
  );
}

export default memo(ReviewHistoryCard);

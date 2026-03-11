"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { format, addDays } from "date-fns";
import { CalendarArrowUp, CalendarDays, Inbox, XCircle } from "lucide-react";
import { useUpdateTask } from "@/hooks/useTasks";
import { useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import type { ReviewSummary } from "@/types/dailyreview";

type RolloverAction = "tomorrow" | "pick" | "backlog" | "skip";

interface ItemDecision {
  action: RolloverAction;
  date?: string;
}

interface Props {
  summary: ReviewSummary;
  onNext: () => void;
}

export default function ReviewRollover({ summary, onNext }: Props) {
  const t = useTranslations("review");
  const tc = useTranslations("common");
  const updateTask = useUpdateTask();
  const updateStudyBlock = useUpdateStudyBlock();
  const tomorrow = format(addDays(new Date(), 1), "yyyy-MM-dd");

  const allItems = [
    ...summary.incomplete_tasks.map((t) => ({
      ...t,
      itemType: "task" as const,
    })),
    ...summary.incomplete_study_blocks.map((sb) => ({
      ...sb,
      itemType: "studyblock" as const,
    })),
  ];

  const [decisions, setDecisions] = useState<Record<string, ItemDecision>>({});
  const [isApplying, setIsApplying] = useState(false);

  if (allItems.length === 0) {
    return (
      <div className="space-y-6 text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          {t("rollover.allDone")}
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          {t("rollover.allDoneSubtitle")}
        </p>
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          {tc("continue")}
        </button>
      </div>
    );
  }

  const allDecided = allItems.every((item) => decisions[item.id]);

  const setDecision = (id: string, decision: ItemDecision) => {
    setDecisions((prev) => ({ ...prev, [id]: decision }));
  };

  const handleApply = async () => {
    setIsApplying(true);
    try {
      for (const item of allItems) {
        const decision = decisions[item.id];
        if (!decision) continue;

        if (item.itemType === "task") {
          if (decision.action === "tomorrow") {
            await updateTask.mutateAsync({
              id: item.id,
              scheduled_date: tomorrow,
            });
          } else if (decision.action === "pick" && decision.date) {
            await updateTask.mutateAsync({
              id: item.id,
              scheduled_date: decision.date,
            });
          } else if (
            decision.action === "backlog" ||
            decision.action === "skip"
          ) {
            await updateTask.mutateAsync({ id: item.id, scheduled_date: null });
          }
        } else {
          if (decision.action === "tomorrow") {
            await updateStudyBlock.mutateAsync({
              id: item.id,
              scheduled_date: tomorrow,
            });
          } else if (decision.action === "pick" && decision.date) {
            await updateStudyBlock.mutateAsync({
              id: item.id,
              scheduled_date: decision.date,
            });
          } else if (decision.action === "backlog") {
            await updateStudyBlock.mutateAsync({
              id: item.id,
              scheduled_date: null,
            });
          } else if (decision.action === "skip") {
            await updateStudyBlock.mutateAsync({
              id: item.id,
              status: "skipped",
            });
          }
        }
      }
      onNext();
    } catch {
      // Error already handled by Toast interceptor
    } finally {
      setIsApplying(false);
    }
  };

  const actionButtons: {
    action: RolloverAction;
    icon: typeof CalendarArrowUp;
    label: string;
  }[] = [
    { action: "tomorrow", icon: CalendarArrowUp, label: t("rollover.tomorrow") },
    { action: "pick", icon: CalendarDays, label: t("rollover.pickDate") },
    { action: "backlog", icon: Inbox, label: t("rollover.backlog") },
    { action: "skip", icon: XCircle, label: t("rollover.skip") },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          {t("rollover.title")}
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          {t("rollover.subtitle")}
        </p>
      </div>

      <div className="space-y-3">
        {allItems.map((item) => {
          const decision = decisions[item.id];
          return (
            <div
              key={item.id}
              className={`rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-opacity ${
                decision ? "opacity-60" : ""
              }`}
            >
              <div className="mb-3 flex items-center justify-between">
                <span className="text-sm font-medium text-[var(--color-text-primary)]">
                  {item.title}
                </span>
                {decision && (
                  <span className="rounded-lg bg-[var(--color-overlay-medium)] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {decision.action === "pick"
                      ? decision.date
                      : decision.action}
                  </span>
                )}
              </div>
              <div className="flex gap-2">
                {actionButtons.map(({ action, icon: Icon, label }) => (
                  <button
                    key={action}
                    onClick={() => {
                      if (action === "pick") {
                        const picked = prompt("Enter date (YYYY-MM-DD):");
                        if (picked) {
                          if (!/^\d{4}-\d{2}-\d{2}$/.test(picked) || isNaN(Date.parse(picked))) {
                            return; // silently reject invalid dates
                          }
                          setDecision(item.id, { action, date: picked });
                        }
                      } else {
                        setDecision(item.id, { action });
                      }
                    }}
                    className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs transition-colors ${
                      decision?.action === action
                        ? "bg-[var(--color-overlay-medium)] text-[var(--color-text-primary)]"
                        : "text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]"
                    }`}
                  >
                    <Icon className="h-3.5 w-3.5" />
                    {label}
                  </button>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      <div className="flex justify-end pt-2">
        <button
          onClick={handleApply}
          disabled={!allDecided || isApplying}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {isApplying ? t("rollover.applying") : t("rollover.applyAndContinue")}
        </button>
      </div>
    </div>
  );
}

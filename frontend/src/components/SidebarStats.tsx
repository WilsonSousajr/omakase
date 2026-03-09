"use client";

import { Flame, Clock, BarChart3 } from "lucide-react";
import { useDailyStats } from "@/hooks/useStats";
import { useTranslations } from "next-intl";

export default function SidebarStats() {
  const t = useTranslations("stats");
  const tAreas = useTranslations("constants.areas");
  const { data: stats } = useDailyStats();

  if (!stats) return null;

  const blockProgress =
    stats.blocks_total_today > 0
      ? Math.round((stats.blocks_completed_today / stats.blocks_total_today) * 100)
      : 0;

  const totalWeeklyHours = stats.weekly_work_hours + stats.weekly_study_hours;

  return (
    <div className="border-t border-[var(--color-border)] px-3 py-3">
      <p className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
        {t("today")}
      </p>

      <div className="space-y-2.5">
        {/* Hours focused */}
        <div className="flex items-center gap-2">
          <Clock className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-faint)]" />
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline justify-between">
              <span className="text-xs text-[var(--color-text-secondary)]">
                {t("hoursFocused", { hours: stats.hours_focused_today })}
              </span>
            </div>
          </div>
        </div>

        {/* Blocks progress */}
        <div className="flex items-center gap-2">
          <BarChart3 className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-faint)]" />
          <div className="min-w-0 flex-1">
            <div className="mb-1 flex items-baseline justify-between">
              <span className="text-xs text-[var(--color-text-secondary)]">
                {t("blocks", { count: `${stats.blocks_completed_today}/${stats.blocks_total_today}` })}
              </span>
            </div>
            <div className="h-1 overflow-hidden rounded-full bg-[var(--color-surface)]">
              <div
                className="h-full rounded-full bg-[var(--color-text-secondary)] transition-all duration-300"
                style={{ width: `${blockProgress}%` }}
              />
            </div>
          </div>
        </div>

        {/* Streak */}
        {stats.current_streak > 0 && (
          <div className="flex items-center gap-2">
            <Flame className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-faint)]" />
            <span className="text-xs text-[var(--color-text-secondary)]">
              {t("streak", { days: stats.current_streak })}
            </span>
          </div>
        )}
      </div>

      {/* Weekly summary */}
      {totalWeeklyHours > 0 && (
        <div className="mt-3 border-t border-[var(--color-border)] pt-2.5">
          <p className="mb-1.5 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            {t("thisWeek")}
          </p>
          <div className="space-y-1">
            {stats.weekly_work_hours > 0 && (
              <div className="flex items-baseline justify-between">
                <span className="text-[11px] text-[var(--color-text-faint)]">{tAreas("work")}</span>
                <span className="text-xs text-[var(--color-text-secondary)]">
                  {stats.weekly_work_hours}h
                </span>
              </div>
            )}
            {stats.weekly_study_hours > 0 && (
              <div className="flex items-baseline justify-between">
                <span className="text-[11px] text-[var(--color-text-faint)]">{tAreas("study")}</span>
                <span className="text-xs text-[var(--color-text-secondary)]">
                  {stats.weekly_study_hours}h
                </span>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

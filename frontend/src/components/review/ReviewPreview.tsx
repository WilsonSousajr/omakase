"use client";

import { useTranslations, useFormatter } from "next-intl";
import { addDays } from "date-fns";
import { useTomorrow } from "@/hooks/useToday";
import { useTimeBlocks } from "@/hooks/useTimeBlocks";
import { useTasks } from "@/hooks/useTasks";
import { useStudyBlocks } from "@/hooks/useStudyBlocks";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";

interface Props {
  onNext: () => void;
}

export default function ReviewPreview({ onNext }: Props) {
  const t = useTranslations("review");
  const tc = useTranslations("constants");
  const fmt = useFormatter();
  const tomorrow = useTomorrow();
  const { data: timeBlocks = [] } = useTimeBlocks(tomorrow, tomorrow);
  const { data: tasks = [] } = useTasks({ scheduled_date: tomorrow });
  const { data: studyBlocks = [] } = useStudyBlocks({
    scheduled_date: tomorrow,
  });
  const { data: classOccurrences = [] } = useClassOccurrences(
    tomorrow,
    tomorrow
  );

  const hasContent =
    timeBlocks.length > 0 ||
    tasks.length > 0 ||
    studyBlocks.length > 0 ||
    classOccurrences.length > 0;

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          {t("preview.title")}
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          {fmt.dateTime(addDays(new Date(), 1), { weekday: "long", month: "long", day: "numeric" })}
        </p>
      </div>

      {!hasContent ? (
        <div className="text-center">
          <p className="text-sm text-[var(--color-text-muted)]">
            {t("preview.nothingScheduled")}
          </p>
          <p className="mt-1 text-xs text-[var(--color-text-faint)]">
            {t("preview.nothingScheduledHint")}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {classOccurrences.map((occ) => (
            <div
              key={occ.id}
              className="flex items-center gap-2 rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <div
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: occ.discipline_color }}
              />
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {occ.discipline_name} — {tc(`classTypes.${occ.class_type}`)}
              </span>
              <span className="text-xs text-[var(--color-text-faint)]">
                {occ.start_time.slice(0, 5)} – {occ.end_time.slice(0, 5)}
              </span>
            </div>
          ))}
          {tasks.map((task) => (
            <div
              key={task.id}
              className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {task.title}
              </span>
            </div>
          ))}
          {studyBlocks.map((sb) => (
            <div
              key={sb.id}
              className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {sb.title}
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="flex justify-end pt-2">
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          {t("preview.finish")}
        </button>
      </div>
    </div>
  );
}

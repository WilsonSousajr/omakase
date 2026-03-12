"use client";

import { useState, useMemo } from "react";
import { useTranslations, useFormatter } from "next-intl";
import { X, ArrowRight, AlertTriangle } from "lucide-react";
import { cn } from "@/lib/utils";
import { useCarriedOverTasks, useCarriedOverStudyBlocks } from "@/hooks/useCarriedOver";
import { useTimeBlocks } from "@/hooks/useTimeBlocks";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";
import { useUpdateTask } from "@/hooks/useTasks";
import { useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useUserProfile } from "@/hooks/useUserProfile";
import { useToday } from "@/hooks/useToday";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";

interface MorningPlanWizardProps {
  onClose: () => void;
}

export default function MorningPlanWizard({ onClose }: MorningPlanWizardProps) {
  const t = useTranslations("plan");
  const tCommon = useTranslations("common");
  const today = useToday();
  const [step, setStep] = useState(0);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="fixed inset-0 bg-black/50" onClick={onClose} />
      <div
        className="relative z-10 flex w-full max-w-2xl flex-col rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)] shadow-xl"
        style={{ maxHeight: "80vh" }}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h2 className="text-sm font-medium text-[var(--color-text-primary)]">
            {t("planMyDay")}
          </h2>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Progress dots */}
        <div className="flex justify-center gap-2 py-3">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className={cn(
                "h-1.5 w-1.5 rounded-full transition-colors",
                i === step
                  ? "bg-[var(--color-text-primary)]"
                  : "bg-[var(--color-border)]"
              )}
            />
          ))}
        </div>

        {/* Step content */}
        <div className="flex-1 overflow-auto px-6 pb-6">
          {step === 0 && <CarriedOverStep today={today} />}
          {step === 1 && <TodayScheduleStep today={today} />}
          {step === 2 && <WorkloadSummaryStep today={today} />}
        </div>

        {/* Footer */}
        <div className="flex justify-between border-t border-[var(--color-border)] px-6 py-4">
          <button
            onClick={() => (step > 0 ? setStep(step - 1) : onClose())}
            className="rounded-xl px-4 py-2 text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)]"
          >
            {step > 0 ? tCommon("back") : tCommon("close")}
          </button>
          {step < 2 ? (
            <button
              onClick={() => setStep(step + 1)}
              className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-4 py-2 text-sm text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)]"
            >
              {tCommon("continue")}
              <ArrowRight className="h-3.5 w-3.5" />
            </button>
          ) : (
            <button
              onClick={onClose}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-2 text-sm text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)]"
            >
              {tCommon("done")}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// Step 1: Carried Over
function CarriedOverStep({ today }: { today: string }) {
  const t = useTranslations("plan");
  const fmt = useFormatter();
  const { data: tasks = [] } = useCarriedOverTasks(today);
  const { data: studyBlocks = [] } = useCarriedOverStudyBlocks(today);
  const updateTask = useUpdateTask();
  const updateStudyBlock = useUpdateStudyBlock();
  const [datePickerItem, setDatePickerItem] = useState<string | null>(null);
  const [pickedDate, setPickedDate] = useState("");

  const handleTaskAction = (taskId: string, action: "today" | "backlog") => {
    if (action === "today") {
      updateTask.mutate({ id: taskId, scheduled_date: today });
    } else {
      updateTask.mutate({ id: taskId, scheduled_date: null });
    }
  };

  const handleTaskPickDate = (taskId: string, date: string) => {
    updateTask.mutate({ id: taskId, scheduled_date: date });
    setDatePickerItem(null);
    setPickedDate("");
  };

  const handleStudyBlockAction = (
    blockId: string,
    action: "today" | "backlog" | "skip"
  ) => {
    if (action === "today") {
      updateStudyBlock.mutate({ id: blockId, scheduled_date: today });
    } else if (action === "backlog") {
      updateStudyBlock.mutate({ id: blockId, scheduled_date: null });
    } else {
      updateStudyBlock.mutate({ id: blockId, status: "skipped" });
    }
  };

  const handleStudyBlockPickDate = (blockId: string, date: string) => {
    updateStudyBlock.mutate({ id: blockId, scheduled_date: date });
    setDatePickerItem(null);
    setPickedDate("");
  };

  const totalItems = tasks.length + studyBlocks.length;

  if (totalItems === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-[var(--color-text-faint)]">
        <p className="text-sm">{t("noCarriedOver")}</p>
      </div>
    );
  }

  return (
    <div>
      <h3 className="mb-1 text-sm font-medium text-[var(--color-text-primary)]">
        {t("carriedOver")}
      </h3>
      <p className="mb-4 text-xs text-[var(--color-text-muted)]">
        {t("carriedOverCount", { count: totalItems })}
      </p>

      <div className="space-y-2">
        {tasks.map((task: Task) => (
          <div
            key={task.id}
            className="flex items-center justify-between rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                {task.title}
              </p>
              {task.scheduled_date && (
                <p className="text-xs text-[var(--color-text-muted)]">
                  {fmt.dateTime(
                    new Date(task.scheduled_date + "T00:00:00"),
                    { month: "short", day: "numeric" }
                  )}
                </p>
              )}
            </div>
            <div className="ml-3 flex shrink-0 gap-1.5">
              <button
                onClick={() => handleTaskAction(task.id, "today")}
                className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)]"
              >
                {t("today")}
              </button>
              <div className="relative">
                <button
                  onClick={() =>
                    setDatePickerItem(
                      datePickerItem === `task-${task.id}`
                        ? null
                        : `task-${task.id}`
                    )
                  }
                  className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)]"
                >
                  {t("pickDate")}
                </button>
                {datePickerItem === `task-${task.id}` && (
                  <div className="absolute right-0 top-full z-10 mt-1 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg)] p-2 shadow-lg">
                    <input
                      type="date"
                      value={pickedDate}
                      onChange={(e) => setPickedDate(e.target.value)}
                      className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-1 text-xs text-[var(--color-text-primary)]"
                    />
                    <button
                      onClick={() =>
                        pickedDate && handleTaskPickDate(task.id, pickedDate)
                      }
                      disabled={!pickedDate}
                      className="mt-1 w-full rounded-lg bg-[var(--color-button-primary)] px-2 py-1 text-xs text-[var(--color-button-primary-text)] disabled:opacity-50"
                    >
                      {t("apply")}
                    </button>
                  </div>
                )}
              </div>
              <button
                onClick={() => handleTaskAction(task.id, "backlog")}
                className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)]"
              >
                {t("backlog")}
              </button>
            </div>
          </div>
        ))}

        {studyBlocks.map((block: StudyBlock) => (
          <div
            key={block.id}
            className="flex items-center justify-between rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
          >
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                {block.title}
              </p>
              {block.scheduled_date && (
                <p className="text-xs text-[var(--color-text-muted)]">
                  {fmt.dateTime(
                    new Date(block.scheduled_date + "T00:00:00"),
                    { month: "short", day: "numeric" }
                  )}
                </p>
              )}
            </div>
            <div className="ml-3 flex shrink-0 gap-1.5">
              <button
                onClick={() => handleStudyBlockAction(block.id, "today")}
                className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)]"
              >
                {t("today")}
              </button>
              <div className="relative">
                <button
                  onClick={() =>
                    setDatePickerItem(
                      datePickerItem === `sb-${block.id}`
                        ? null
                        : `sb-${block.id}`
                    )
                  }
                  className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)]"
                >
                  {t("pickDate")}
                </button>
                {datePickerItem === `sb-${block.id}` && (
                  <div className="absolute right-0 top-full z-10 mt-1 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg)] p-2 shadow-lg">
                    <input
                      type="date"
                      value={pickedDate}
                      onChange={(e) => setPickedDate(e.target.value)}
                      className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-1 text-xs text-[var(--color-text-primary)]"
                    />
                    <button
                      onClick={() =>
                        pickedDate &&
                        handleStudyBlockPickDate(block.id, pickedDate)
                      }
                      disabled={!pickedDate}
                      className="mt-1 w-full rounded-lg bg-[var(--color-button-primary)] px-2 py-1 text-xs text-[var(--color-button-primary-text)] disabled:opacity-50"
                    >
                      {t("apply")}
                    </button>
                  </div>
                )}
              </div>
              <button
                onClick={() => handleStudyBlockAction(block.id, "backlog")}
                className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)]"
              >
                {t("backlog")}
              </button>
              <button
                onClick={() => handleStudyBlockAction(block.id, "skip")}
                className="rounded-lg px-2.5 py-1 text-[10px] font-medium text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)]"
              >
                {t("skipStudyBlock")}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// Step 2: Today's Schedule
function TodayScheduleStep({ today }: { today: string }) {
  const t = useTranslations("plan");
  const { data: timeBlocks = [] } = useTimeBlocks(today, today);
  const { data: classOccurrences = [] } = useClassOccurrences(today, today);

  const allItems = useMemo(() => {
    const items: Array<{
      type: "timeblock" | "class";
      title: string;
      start_time: string;
      end_time: string;
      source: string;
    }> = [];

    timeBlocks.forEach((tb) => {
      items.push({
        type: "timeblock",
        title: tb.task ? "Task" : "Study",
        start_time: tb.start_time,
        end_time: tb.end_time,
        source: "",
      });
    });

    classOccurrences.forEach((co) => {
      items.push({
        type: "class",
        title: co.discipline_name,
        start_time: co.start_time,
        end_time: co.end_time,
        source: co.class_type,
      });
    });

    return items.sort((a, b) => a.start_time.localeCompare(b.start_time));
  }, [timeBlocks, classOccurrences]);

  const totalMinutes = allItems.reduce((acc, item) => {
    const [sh, sm] = item.start_time.split(":").map(Number);
    const [eh, em] = item.end_time.split(":").map(Number);
    return acc + (eh * 60 + em) - (sh * 60 + sm);
  }, 0);
  const totalHours = (totalMinutes / 60).toFixed(1);

  return (
    <div>
      <h3 className="mb-4 text-sm font-medium text-[var(--color-text-primary)]">
        {t("todaysSchedule")}
      </h3>

      {allItems.length === 0 ? (
        <p className="py-8 text-center text-xs text-[var(--color-text-faint)]">
          {t("noScheduledItems")}
        </p>
      ) : (
        <>
          <div className="space-y-2">
            {allItems.map((item, i) => (
              <div
                key={i}
                className="flex items-center gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
              >
                <span className="text-xs font-medium tabular-nums text-[var(--color-text-muted)]">
                  {item.start_time.slice(0, 5)} &ndash;{" "}
                  {item.end_time.slice(0, 5)}
                </span>
                <span className="truncate text-sm text-[var(--color-text-primary)]">
                  {item.title}
                </span>
                {item.source && (
                  <span className="shrink-0 rounded-lg bg-[var(--color-hover-overlay)] px-1.5 py-0.5 text-[10px] text-[var(--color-text-muted)]">
                    {item.source}
                  </span>
                )}
              </div>
            ))}
          </div>
          <p className="mt-4 text-xs text-[var(--color-text-muted)]">
            {t("totalPlannedHours", { hours: totalHours })}
          </p>
        </>
      )}
    </div>
  );
}

// Step 3: Workload Summary
function WorkloadSummaryStep({ today }: { today: string }) {
  const t = useTranslations("plan");
  const { data: timeBlocks = [] } = useTimeBlocks(today, today);
  const { data: classOccurrences = [] } = useClassOccurrences(today, today);
  const { data: profile } = useUserProfile();

  const workMinutes = timeBlocks
    .filter((tb) => tb.task)
    .reduce((acc, tb) => {
      const [sh, sm] = tb.start_time.split(":").map(Number);
      const [eh, em] = tb.end_time.split(":").map(Number);
      return acc + (eh * 60 + em) - (sh * 60 + sm);
    }, 0);

  const studyMinutes =
    timeBlocks
      .filter((tb) => tb.study_block)
      .reduce((acc, tb) => {
        const [sh, sm] = tb.start_time.split(":").map(Number);
        const [eh, em] = tb.end_time.split(":").map(Number);
        return acc + (eh * 60 + em) - (sh * 60 + sm);
      }, 0) +
    classOccurrences.reduce((acc, co) => {
      const [sh, sm] = co.start_time.split(":").map(Number);
      const [eh, em] = co.end_time.split(":").map(Number);
      return acc + (eh * 60 + em) - (sh * 60 + sm);
    }, 0);

  const workHours = (workMinutes / 60).toFixed(1);
  const studyHours = (studyMinutes / 60).toFixed(1);
  const totalHours = ((workMinutes + studyMinutes) / 60).toFixed(1);
  const goalHours =
    (profile?.daily_work_goal_hours || 8) +
    (profile?.daily_study_goal_hours || 4);
  const isOverGoal = (workMinutes + studyMinutes) / 60 > goalHours;

  return (
    <div>
      <h3 className="mb-4 text-sm font-medium text-[var(--color-text-primary)]">
        {t("workloadSummary")}
      </h3>

      <div className="space-y-3">
        <div className="flex justify-between rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <span className="text-sm text-[var(--color-text-secondary)]">
            {t("work")}
          </span>
          <span className="text-sm font-medium text-[var(--color-text-primary)]">
            {workHours}h
          </span>
        </div>
        <div className="flex justify-between rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <span className="text-sm text-[var(--color-text-secondary)]">
            {t("studyLabel")}
          </span>
          <span className="text-sm font-medium text-[var(--color-text-primary)]">
            {studyHours}h
          </span>
        </div>
      </div>

      {isOverGoal && (
        <div className="mt-4 flex items-start gap-2 rounded-xl border border-amber-500/20 bg-amber-500/5 p-3">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-500" />
          <p className="text-xs text-amber-500">
            {t("workloadWarning", {
              planned: totalHours,
              goal: goalHours.toFixed(1),
            })}
          </p>
        </div>
      )}
    </div>
  );
}

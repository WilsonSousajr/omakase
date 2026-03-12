"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { DndContext, DragOverlay, type DragEndEvent, type DragStartEvent, PointerSensor, useSensor, useSensors, closestCenter } from "@dnd-kit/core";
import { format, startOfWeek, addDays } from "date-fns";
import TaskList from "@/components/tasks/TaskList";
import Calendar from "@/components/calendar/Calendar";
import MorningPlanWizard from "@/components/plan/MorningPlanWizard";
import OverlapWarning from "@/components/calendar/OverlapWarning";
import { useTranslations } from "next-intl";
import { emitToast } from "@/components/Toast";
import { useCreateTimeBlock, useUpdateTimeBlock, useTimeBlocks } from "@/hooks/useTimeBlocks";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";
import { useUpdateTask } from "@/hooks/useTasks";
import { useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDailyReview } from "@/hooks/useDailyReviews";
import { useToday } from "@/hooks/useToday";
import { useUIStore } from "@/stores/uiStore";
import { useCalendarStore } from "@/stores/calendarStore";
import { findOverlaps } from "@/lib/timeblock-utils";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";
import type { TimeBlock } from "@/types/timeblock";
import { DRAG_ACTIVATION_DISTANCE, DEFAULT_TIMEBLOCK_MINUTES, PRIORITIES } from "@/lib/constants";

function addMinutesToTime(time: string, minutes: number): string {
  const [h, m] = time.split(":").map(Number);
  const total = Math.min(h * 60 + m + minutes, 22 * 60);
  const newH = Math.floor(total / 60);
  const newM = total % 60;
  return `${newH.toString().padStart(2, "0")}:${newM.toString().padStart(2, "0")}:00`;
}

export default function PlanPage() {
  const t = useTranslations("plan");
  const createTimeBlock = useCreateTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();
  const updateTask = useUpdateTask();
  const updateStudyBlock = useUpdateStudyBlock();
  const [showWizard, setShowWizard] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [activeDrag, setActiveDrag] = useState<
    | { type: "task"; task: Task }
    | { type: "studyblock"; studyBlock: StudyBlock }
    | { type: "timeblock"; block: TimeBlock; title: string; color: string }
    | null
  >(null);

  // Overlap detection state
  const [pendingAction, setPendingAction] = useState<(() => Promise<void>) | null>(null);
  const [overlaps, setOverlaps] = useState<Array<{ title: string; start_time: string; end_time: string }>>([]);

  const today = useToday();
  const { data: todayReview } = useDailyReview(today);
  const hasShownShutdownNudge = useUIStore((s) => s.hasShownShutdownNudge);
  const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);
  const openModal = useUIStore((s) => s.openModal);
  const setCreationDraft = useCalendarStore((s) => s.setCreationDraft);
  const selectedDate = useCalendarStore((s) => s.selectedDate);
  const viewMode = useCalendarStore((s) => s.viewMode);

  // Compute date range matching the calendar view for overlap checking
  const { dateFrom, dateTo } = useMemo(() => {
    if (viewMode === "week") {
      const weekStart = startOfWeek(selectedDate, { weekStartsOn: 1 });
      return {
        dateFrom: format(weekStart, "yyyy-MM-dd"),
        dateTo: format(addDays(weekStart, 6), "yyyy-MM-dd"),
      };
    }
    const d = format(selectedDate, "yyyy-MM-dd");
    return { dateFrom: d, dateTo: d };
  }, [selectedDate, viewMode]);

  const { data: existingBlocks = [] } = useTimeBlocks(dateFrom, dateTo);
  const { data: classOccs = [] } = useClassOccurrences(dateFrom, dateTo);

  useEffect(() => {
    if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
      emitToast(t("shutdownNudge"));
      setHasShownShutdownNudge(true);
    }
  }, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: DRAG_ACTIVATION_DISTANCE } })
  );

  const handleDragStart = (event: DragStartEvent) => {
    setIsDragging(true);
    setActiveDrag(event.active.data.current as typeof activeDrag);
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    setIsDragging(false);
    setActiveDrag(null);
    const { active, over } = event;
    if (!over) return;

    const overData = over.data.current as { type: string; date: string; time: string } | undefined;
    if (!overData || overData.type !== "timeslot") return;

    const activeData = active.data.current as
      | { type: "task"; task: Task }
      | { type: "studyblock"; studyBlock: StudyBlock }
      | { type: "timeblock"; block: TimeBlock }
      | undefined;
    if (!activeData) return;

    const { date, time } = overData;

    // Compute proposed time range for overlap detection
    let proposedEnd: string;
    let excludeId: string | undefined;

    if (activeData.type === "task") {
      const duration = activeData.task.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
      proposedEnd = addMinutesToTime(time, duration);
    } else if (activeData.type === "studyblock") {
      const duration = activeData.studyBlock.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
      proposedEnd = addMinutesToTime(time, duration);
    } else {
      const block = activeData.block;
      const [startH, startM] = block.start_time.split(":").map(Number);
      const [endH, endM] = block.end_time.split(":").map(Number);
      const durationMin = (endH * 60 + endM) - (startH * 60 + startM);
      proposedEnd = addMinutesToTime(time, durationMin);
      excludeId = block.id;
    }

    const detectedOverlaps = findOverlaps(
      { date, start_time: time + ":00", end_time: proposedEnd },
      existingBlocks,
      classOccs,
      excludeId,
    );

    const executeMutation = async () => {
      // Fire all mutations in parallel so React 18 batches the cache
      // invalidations into a single re-render (prevents intermediate glitch state)
      try {
        if (activeData.type === "task") {
          const duration = activeData.task.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
          const promises: Promise<unknown>[] = [
            createTimeBlock.mutateAsync({
              task: activeData.task.id,
              date,
              start_time: time + ":00",
              end_time: addMinutesToTime(time, duration),
            }),
          ];
          if (activeData.task.scheduled_date !== date) {
            promises.push(updateTask.mutateAsync({ id: activeData.task.id, scheduled_date: date }));
          }
          await Promise.all(promises);
        } else if (activeData.type === "studyblock") {
          const sb = activeData.studyBlock;
          const duration = sb.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
          const promises: Promise<unknown>[] = [
            createTimeBlock.mutateAsync({
              study_block: sb.id,
              date,
              start_time: time + ":00",
              end_time: addMinutesToTime(time, duration),
            }),
          ];
          if (sb.scheduled_date !== date) {
            promises.push(updateStudyBlock.mutateAsync({ id: sb.id, scheduled_date: date }));
          }
          await Promise.all(promises);
        } else if (activeData.type === "timeblock") {
          const block = activeData.block;
          const [startH, startM] = block.start_time.split(":").map(Number);
          const [endH, endM] = block.end_time.split(":").map(Number);
          const durationMin = (endH * 60 + endM) - (startH * 60 + startM);

          const promises: Promise<unknown>[] = [
            updateTimeBlock.mutateAsync({
              id: block.id,
              date,
              start_time: time + ":00",
              end_time: addMinutesToTime(time, durationMin),
            }),
          ];
          if (block.task && block.date !== date) {
            promises.push(updateTask.mutateAsync({ id: block.task, scheduled_date: date }));
          } else if (block.study_block && block.date !== date) {
            promises.push(updateStudyBlock.mutateAsync({ id: block.study_block, scheduled_date: date }));
          }
          await Promise.all(promises);
        }
      } catch {
        // Errors handled by global toast interceptor
      }
    };

    if (detectedOverlaps.length > 0) {
      setOverlaps(detectedOverlaps);
      setPendingAction(() => executeMutation);
    } else {
      await executeMutation();
    }
  };

  const handleCreateRange = useCallback(
    (date: string, startTime: string, endTime: string) => {
      const detectedOverlaps = findOverlaps(
        { date, start_time: startTime + ":00", end_time: endTime + ":00" },
        existingBlocks,
        classOccs,
      );

      if (detectedOverlaps.length > 0) {
        setOverlaps(detectedOverlaps);
        setPendingAction(() => async () => {
          setCreationDraft({ date, startTime, endTime });
          openModal("task-form");
        });
      } else {
        setCreationDraft({ date, startTime, endTime });
        openModal("task-form");
      }
    },
    [setCreationDraft, openModal, existingBlocks, classOccs],
  );

  const handleOverlapConfirm = async () => {
    if (pendingAction) {
      await pendingAction();
    }
    setOverlaps([]);
    setPendingAction(null);
  };

  const handleOverlapCancel = () => {
    setOverlaps([]);
    setPendingAction(null);
  };

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div className="flex h-full">
        <div className="w-[400px] shrink-0 border-r border-[var(--color-border)]">
          <div className="flex items-center justify-between border-b border-[var(--color-border)] px-4 py-3">
            <h2 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-secondary)]">
              {t("tasks")}
            </h2>
            <button
              onClick={() => setShowWizard(true)}
              className="rounded-xl px-3 py-1.5 text-xs font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)]"
            >
              {t("planMyDay")}
            </button>
          </div>
          <TaskList />
        </div>
        <div className="flex-1">
          <Calendar isDragging={isDragging} onCreateRange={handleCreateRange} />
        </div>
      </div>

      {showWizard && <MorningPlanWizard onClose={() => setShowWizard(false)} />}

      <DragOverlay dropAnimation={null}>
        {activeDrag?.type === "task" && (() => {
          const priority = PRIORITIES.find((p) => p.value === activeDrag.task.priority);
          return (
            <div className="w-[350px] rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 shadow-xl shadow-black/25">
              <div className="flex items-center gap-2">
                <span className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                  {activeDrag.task.title}
                </span>
                {priority && (
                  <span
                    className="shrink-0 rounded-lg px-1.5 py-0.5 text-[10px] font-medium"
                    style={{ backgroundColor: priority.color + "20", color: priority.color }}
                  >
                    {priority.label}
                  </span>
                )}
              </div>
            </div>
          );
        })()}
        {activeDrag?.type === "timeblock" && (
          <div
            className="relative w-[200px] rounded-xl border pl-3.5 pr-3 py-1.5 shadow-xl shadow-black/25"
            style={{
              borderColor: `${activeDrag.color}25`,
              backgroundColor: `${activeDrag.color}12`,
            }}
          >
            <div
              className="absolute left-0 top-0 bottom-0 w-1 rounded-l-xl"
              style={{ backgroundColor: activeDrag.color }}
            />
            <p className="truncate text-xs font-medium text-[var(--color-text-primary)]">
              {activeDrag.title}
            </p>
          </div>
        )}
        {activeDrag?.type === "studyblock" && (
          <div className="w-[350px] rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 shadow-xl shadow-black/25">
            <span className="truncate text-sm font-medium text-[var(--color-text-primary)]">
              {activeDrag.studyBlock.title}
            </span>
          </div>
        )}
      </DragOverlay>

      {overlaps.length > 0 && (
        <OverlapWarning
          overlaps={overlaps}
          onConfirm={handleOverlapConfirm}
          onCancel={handleOverlapCancel}
        />
      )}
    </DndContext>
  );
}

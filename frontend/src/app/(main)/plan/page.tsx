"use client";

import { useEffect } from "react";
import { DndContext, type DragEndEvent, PointerSensor, useSensor, useSensors } from "@dnd-kit/core";
import TaskList from "@/components/tasks/TaskList";
import Calendar from "@/components/calendar/Calendar";
import { emitToast } from "@/components/Toast";
import { useCreateTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useUpdateTask } from "@/hooks/useTasks";
import { useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDailyReview } from "@/hooks/useDailyReviews";
import { useToday } from "@/hooks/useToday";
import { useUIStore } from "@/stores/uiStore";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";
import type { TimeBlock } from "@/types/timeblock";
import { DRAG_ACTIVATION_DISTANCE, DEFAULT_TIMEBLOCK_MINUTES } from "@/lib/constants";

function addMinutesToTime(time: string, minutes: number): string {
  const [h, m] = time.split(":").map(Number);
  const total = Math.min(h * 60 + m + minutes, 22 * 60);
  const newH = Math.floor(total / 60);
  const newM = total % 60;
  return `${newH.toString().padStart(2, "0")}:${newM.toString().padStart(2, "0")}:00`;
}

export default function PlanPage() {
  const createTimeBlock = useCreateTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();
  const updateTask = useUpdateTask();
  const updateStudyBlock = useUpdateStudyBlock();

  const today = useToday();
  const { data: todayReview } = useDailyReview(today);
  const hasShownShutdownNudge = useUIStore((s) => s.hasShownShutdownNudge);
  const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);

  useEffect(() => {
    if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
      emitToast("You've shut down for the day. Rest well!");
      setHasShownShutdownNudge(true);
    }
  }, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: DRAG_ACTIVATION_DISTANCE } })
  );

  const handleDragEnd = async (event: DragEndEvent) => {
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

    if (activeData.type === "task") {
      const duration = activeData.task.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
      try {
        await createTimeBlock.mutateAsync({
          task: activeData.task.id,
          date,
          start_time: time + ":00",
          end_time: addMinutesToTime(time, duration),
        });
        // Set scheduled_date so the task appears in focus mode
        if (activeData.task.scheduled_date !== date) {
          await updateTask.mutateAsync({ id: activeData.task.id, scheduled_date: date });
        }
      } catch {
        // Errors handled by global toast interceptor
      }
    } else if (activeData.type === "studyblock") {
      const sb = activeData.studyBlock;
      const duration = sb.estimated_minutes || DEFAULT_TIMEBLOCK_MINUTES;
      try {
        await createTimeBlock.mutateAsync({
          study_block: sb.id,
          date,
          start_time: time + ":00",
          end_time: addMinutesToTime(time, duration),
        });
        if (sb.scheduled_date !== date) {
          await updateStudyBlock.mutateAsync({ id: sb.id, scheduled_date: date });
        }
      } catch {
        // Errors handled by global toast interceptor
      }
    } else if (activeData.type === "timeblock") {
      const block = activeData.block;
      const [startH, startM] = block.start_time.split(":").map(Number);
      const [endH, endM] = block.end_time.split(":").map(Number);
      const durationMin = (endH * 60 + endM) - (startH * 60 + startM);

      updateTimeBlock.mutate({
        id: block.id,
        date,
        start_time: time + ":00",
        end_time: addMinutesToTime(time, durationMin),
      });
    }
  };

  return (
    <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
      <div className="flex h-full">
        <div className="w-[400px] shrink-0 border-r border-[var(--color-border)]">
          <TaskList />
        </div>
        <div className="flex-1">
          <Calendar />
        </div>
      </div>
    </DndContext>
  );
}

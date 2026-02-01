"use client";

import { DndContext, type DragEndEvent, PointerSensor, useSensor, useSensors } from "@dnd-kit/core";
import TaskList from "@/components/tasks/TaskList";
import Calendar from "@/components/calendar/Calendar";
import { useCreateTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useUpdateTask } from "@/hooks/useTasks";
import type { Task } from "@/types/task";
import type { TimeBlock } from "@/types/timeblock";

function addMinutesToTime(time: string, minutes: number): string {
  const [h, m] = time.split(":").map(Number);
  const total = h * 60 + m + minutes;
  const newH = Math.floor(total / 60);
  const newM = total % 60;
  return `${newH.toString().padStart(2, "0")}:${newM.toString().padStart(2, "0")}:00`;
}

export default function PlanPage() {
  const createTimeBlock = useCreateTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();
  const updateTask = useUpdateTask();

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  );

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (!over) return;

    const overData = over.data.current as { type: string; date: string; time: string } | undefined;
    if (!overData || overData.type !== "timeslot") return;

    const activeData = active.data.current as
      | { type: "task"; task: Task }
      | { type: "timeblock"; block: TimeBlock }
      | undefined;
    if (!activeData) return;

    const { date, time } = overData;

    if (activeData.type === "task") {
      const duration = activeData.task.estimated_minutes || 30;
      createTimeBlock.mutate({
        task: activeData.task.id,
        date,
        start_time: time + ":00",
        end_time: addMinutesToTime(time, duration),
      });
      // Set scheduled_date so the task appears in focus mode
      if (activeData.task.scheduled_date !== date) {
        updateTask.mutate({ id: activeData.task.id, scheduled_date: date });
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
        <div className="w-[400px] shrink-0 border-r border-zinc-800">
          <TaskList />
        </div>
        <div className="flex-1">
          <Calendar />
        </div>
      </div>
    </DndContext>
  );
}

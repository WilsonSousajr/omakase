"use client";

import { useMemo } from "react";
import { useDroppable } from "@dnd-kit/core";
import { format } from "date-fns";
import { useCalendarStore } from "@/stores/calendarStore";
import { useTimeBlocks, useDeleteTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useTasks, useToggleTaskComplete } from "@/hooks/useTasks";
import { useStudyBlocks, useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDisciplines } from "@/hooks/useDisciplines";
import TimeBlockItem from "./TimeBlockItem";

const HOURS = Array.from({ length: 17 }, (_, i) => i + 6); // 06:00 - 22:00
const SLOT_HEIGHT = 48;

function TimeSlot({ hour, half, date }: { hour: number; half: 0 | 1; date: string }) {
  const time = `${hour.toString().padStart(2, "0")}:${half === 0 ? "00" : "30"}`;
  const droppableId = `slot-${date}-${time}`;

  const { setNodeRef, isOver } = useDroppable({
    id: droppableId,
    data: { type: "timeslot", date, time },
  });

  return (
    <div
      ref={setNodeRef}
      className={`h-[${SLOT_HEIGHT / 2}px] border-b border-[var(--color-border)]/50 transition-colors ${
        half === 0 ? "border-t border-[var(--color-border)]" : ""
      } ${isOver ? "bg-white/5" : ""}`}
      style={{ height: `${SLOT_HEIGHT / 2}px` }}
    />
  );
}

export default function CalendarDayView() {
  const { selectedDate } = useCalendarStore();
  const dateStr = format(selectedDate, "yyyy-MM-dd");

  const { data: timeBlocks = [] } = useTimeBlocks(dateStr, dateStr);
  const { data: tasks = [] } = useTasks();
  const { data: studyBlocks = [] } = useStudyBlocks();
  const { data: disciplines = [] } = useDisciplines();
  const deleteTimeBlock = useDeleteTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();
  const toggleComplete = useToggleTaskComplete();
  const updateStudyBlock = useUpdateStudyBlock();

  const taskMap = useMemo(() => Object.fromEntries(tasks.map((t) => [t.id, t])), [tasks]);
  const studyBlockMap = useMemo(() => Object.fromEntries(studyBlocks.map((sb) => [sb.id, sb])), [studyBlocks]);
  const disciplineMap = useMemo(() => Object.fromEntries(disciplines.map((d) => [d.id, d])), [disciplines]);

  const handleToggleComplete = (id: string, isCompleted: boolean) => {
    toggleComplete.mutate({ id, is_completed: isCompleted });
  };

  const handleToggleStudyBlockComplete = (id: string, isCompleted: boolean) => {
    updateStudyBlock.mutate({ id, is_completed: isCompleted });
  };

  function timeToOffset(time: string): number {
    const [h, m] = time.split(":").map(Number);
    return ((h - 6) * 60 + m) / 30 * (SLOT_HEIGHT / 2);
  }

  return (
    <div className="flex-1 overflow-auto">
      <div className="relative flex">
        {/* Time labels */}
        <div className="w-14 shrink-0">
          {HOURS.map((hour) => (
            <div
              key={hour}
              className="flex items-start justify-end pr-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]"
              style={{ height: `${SLOT_HEIGHT}px` }}
            >
              {format(new Date(2000, 0, 1, hour), "h a")}
            </div>
          ))}
        </div>

        {/* Grid + blocks */}
        <div className="relative flex-1">
          {/* Slots */}
          {HOURS.map((hour) => (
            <div key={hour}>
              <TimeSlot hour={hour} half={0} date={dateStr} />
              <TimeSlot hour={hour} half={1} date={dateStr} />
            </div>
          ))}

          {/* Time blocks */}
          {timeBlocks.map((block) => {
            const studyBlock = block.study_block ? studyBlockMap[block.study_block] : undefined;
            const discipline = studyBlock ? disciplineMap[studyBlock.discipline] : undefined;
            return (
              <div
                key={block.id}
                className="absolute left-0 right-0"
                style={{ top: `${timeToOffset(block.start_time)}px` }}
              >
                <TimeBlockItem
                  block={block}
                  task={block.task ? taskMap[block.task] : undefined}
                  studyBlock={studyBlock}
                  disciplineColor={discipline?.color}
                  onDelete={(id) => deleteTimeBlock.mutate(id)}
                  onResize={(id, newEndTime) =>
                    updateTimeBlock.mutate({ id, end_time: newEndTime })
                  }
                  onToggleComplete={handleToggleComplete}
                  onToggleStudyBlockComplete={handleToggleStudyBlockComplete}
                  slotHeight={SLOT_HEIGHT}
                />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

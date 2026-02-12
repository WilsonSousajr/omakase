"use client";

import { format, startOfWeek, addDays } from "date-fns";
import { useCalendarStore } from "@/stores/calendarStore";
import { useTimeBlocks, useDeleteTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useTasks } from "@/hooks/useTasks";
import { useDroppable } from "@dnd-kit/core";
import TimeBlockItem from "./TimeBlockItem";

const HOURS = Array.from({ length: 17 }, (_, i) => i + 6);
const SLOT_HEIGHT = 40;

function WeekTimeSlot({ hour, half, date }: { hour: number; half: 0 | 1; date: string }) {
  const time = `${hour.toString().padStart(2, "0")}:${half === 0 ? "00" : "30"}`;
  const droppableId = `slot-${date}-${time}`;

  const { setNodeRef, isOver } = useDroppable({
    id: droppableId,
    data: { type: "timeslot", date, time },
  });

  return (
    <div
      ref={setNodeRef}
      className={`border-b border-[var(--color-border)]/30 transition-colors ${
        half === 0 ? "border-t border-[var(--color-border)]/50" : ""
      } ${isOver ? "bg-white/5" : ""}`}
      style={{ height: `${SLOT_HEIGHT / 2}px` }}
    />
  );
}

export default function CalendarWeekView() {
  const { selectedDate } = useCalendarStore();
  const weekStart = startOfWeek(selectedDate, { weekStartsOn: 1 });
  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  const dateFrom = format(days[0], "yyyy-MM-dd");
  const dateTo = format(days[6], "yyyy-MM-dd");

  const { data: timeBlocks = [] } = useTimeBlocks(dateFrom, dateTo);
  const { data: tasks = [] } = useTasks();
  const deleteTimeBlock = useDeleteTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();

  const taskMap = Object.fromEntries(tasks.map((t) => [t.id, t]));

  function timeToOffset(time: string): number {
    const [h, m] = time.split(":").map(Number);
    return ((h - 6) * 60 + m) / 30 * (SLOT_HEIGHT / 2);
  }

  const blocksByDate = timeBlocks.reduce(
    (acc, b) => {
      (acc[b.date] ??= []).push(b);
      return acc;
    },
    {} as Record<string, typeof timeBlocks>
  );

  return (
    <div className="flex-1 overflow-auto">
      <div className="flex">
        {/* Time labels */}
        <div className="w-12 shrink-0">
          <div className="h-8" />
          {HOURS.map((hour) => (
            <div
              key={hour}
              className="flex items-start justify-end pr-1.5 text-[9px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]"
              style={{ height: `${SLOT_HEIGHT}px` }}
            >
              {format(new Date(2000, 0, 1, hour), "ha")}
            </div>
          ))}
        </div>

        {/* Day columns */}
        {days.map((day) => {
          const dayStr = format(day, "yyyy-MM-dd");
          const isToday = dayStr === format(new Date(), "yyyy-MM-dd");
          const dayBlocks = blocksByDate[dayStr] || [];

          return (
            <div key={dayStr} className="relative flex-1 border-l border-[var(--color-border)]/50">
              {/* Day header */}
              <div className="sticky top-0 z-10 flex h-8 items-center justify-center border-b border-[var(--color-border)] bg-[var(--color-bg)]">
                <span
                  className={`text-[10px] font-medium ${
                    isToday ? "text-[var(--color-text-primary)]" : "text-[var(--color-text-muted)]"
                  }`}
                >
                  {format(day, "EEE d")}
                </span>
              </div>

              {/* Slots */}
              <div className="relative">
                {HOURS.map((hour) => (
                  <div key={hour}>
                    <WeekTimeSlot hour={hour} half={0} date={dayStr} />
                    <WeekTimeSlot hour={hour} half={1} date={dayStr} />
                  </div>
                ))}

                {/* Time blocks */}
                {dayBlocks.map((block) => (
                  <div
                    key={block.id}
                    className="absolute left-0 right-0"
                    style={{ top: `${timeToOffset(block.start_time)}px` }}
                  >
                    <TimeBlockItem
                      block={block}
                      task={taskMap[block.task]}
                      onDelete={(id) => deleteTimeBlock.mutate(id)}
                      onResize={(id, newEndTime) =>
                        updateTimeBlock.mutate({ id, end_time: newEndTime })
                      }
                      slotHeight={SLOT_HEIGHT}
                    />
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

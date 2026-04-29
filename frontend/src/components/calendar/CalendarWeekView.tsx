"use client";

import { useMemo } from "react";
import { format, startOfWeek, addDays } from "date-fns";
import { useFormatter } from "next-intl";
import { useCalendarStore } from "@/stores/calendarStore";
import { useTimeBlocks, useDeleteTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useTasks, useToggleTaskComplete } from "@/hooks/useTasks";
import { useStudyBlocks, useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDisciplines } from "@/hooks/useDisciplines";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";
import TimeBlockItem from "./TimeBlockItem";
import ClassBlockItem from "./ClassBlockItem";
import TimeSlot from "./TimeSlot";
import CurrentTimeIndicator from "./CurrentTimeIndicator";
import { timeToOffset, HOURS, SLOT_HEIGHT_WEEK } from "./calendarUtils";

interface CalendarWeekViewProps {
  isDragging?: boolean;
  onCreateRange?: (date: string, startTime: string, endTime: string) => void;
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export default function CalendarWeekView({ isDragging, onCreateRange }: CalendarWeekViewProps) {
  const fmt = useFormatter();
  const { selectedDate } = useCalendarStore();
  const weekStart = startOfWeek(selectedDate, { weekStartsOn: 1 });
  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));

  const dateFrom = format(days[0], "yyyy-MM-dd");
  const dateTo = format(days[6], "yyyy-MM-dd");

  const { data: timeBlocks = [] } = useTimeBlocks(dateFrom, dateTo);
  const { data: tasks = [] } = useTasks();
  const { data: studyBlocks = [] } = useStudyBlocks();
  const { data: disciplines = [] } = useDisciplines();
  const { data: classOccurrences = [] } = useClassOccurrences(dateFrom, dateTo);
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

  const blocksByDate = timeBlocks.reduce(
    (acc, b) => {
      (acc[b.date] ??= []).push(b);
      return acc;
    },
    {} as Record<string, typeof timeBlocks>
  );

  const occurrencesByDate = classOccurrences.reduce(
    (acc, o) => {
      (acc[o.date] ??= []).push(o);
      return acc;
    },
    {} as Record<string, typeof classOccurrences>
  );

  return (
    <div className="flex-1 overflow-auto">
      <div className="flex">
        {/* Time labels */}
        <div className="w-12 shrink-0">
          <div className="h-12" />
          {HOURS.map((hour) => (
            <div
              key={hour}
              className="relative flex items-start justify-end pr-1.5 text-[9px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]"
              style={{ height: `${SLOT_HEIGHT_WEEK}px` }}
            >
              <span className="relative -top-[5px]">
                {fmt.dateTime(new Date(2000, 0, 1, hour), { hour: "numeric", hour12: true })}
              </span>
            </div>
          ))}
        </div>

        {/* Day columns */}
        {days.map((day) => {
          const dayStr = format(day, "yyyy-MM-dd");
          const isToday = dayStr === format(new Date(), "yyyy-MM-dd");
          const dayBlocks = blocksByDate[dayStr] || [];
          const dayOccurrences = occurrencesByDate[dayStr] || [];

          return (
            <div key={dayStr} className={`relative flex-1 border-l border-[var(--color-border)]/30 ${isToday ? "bg-[var(--color-hover-overlay)]" : ""}`}>
              {/* Day header */}
              <div className="sticky top-0 z-10 flex h-12 flex-col items-center justify-center border-b border-[var(--color-border)] bg-[var(--color-bg)]">
                <span className={`text-[10px] font-medium uppercase ${
                  isToday ? "text-[var(--color-text-secondary)]" : "text-[var(--color-text-faint)]"
                }`}>
                  {fmt.dateTime(day, { weekday: "short" })}
                </span>
                <span className={`mt-0.5 flex h-6 w-6 items-center justify-center text-xs font-semibold ${
                  isToday
                    ? "rounded-full bg-[var(--color-text-primary)] text-[var(--color-bg)]"
                    : "text-[var(--color-text-muted)]"
                }`}>
                  {format(day, "d")}
                </span>
              </div>

              {/* Slots */}
              <div className="relative">
                {HOURS.map((hour) => (
                  <div key={hour}>
                    <TimeSlot hour={hour} half={0} date={dayStr} height={SLOT_HEIGHT_WEEK / 2} />
                    <TimeSlot hour={hour} half={1} date={dayStr} height={SLOT_HEIGHT_WEEK / 2} />
                  </div>
                ))}

                {/* Current time indicator (only today column) */}
                <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_WEEK} isToday={isToday} />

                {/* Class occurrences (read-only, dashed) */}
                {dayOccurrences.map((occ) => (
                  <div
                    key={occ.id}
                    className="absolute left-0 right-0"
                    style={{ top: `${timeToOffset(occ.start_time, SLOT_HEIGHT_WEEK)}px` }}
                  >
                    <ClassBlockItem occurrence={occ} slotHeight={SLOT_HEIGHT_WEEK} />
                  </div>
                ))}

                {/* Time blocks */}
                {dayBlocks.map((block) => {
                  const studyBlock = block.study_block ? studyBlockMap[block.study_block] : undefined;
                  const discipline = studyBlock ? disciplineMap[studyBlock.discipline] : undefined;
                  return (
                    <div
                      key={block.id}
                      className="absolute left-0 right-0"
                      style={{ top: `${timeToOffset(block.start_time, SLOT_HEIGHT_WEEK)}px` }}
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
                        slotHeight={SLOT_HEIGHT_WEEK}
                      />
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

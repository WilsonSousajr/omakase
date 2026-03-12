"use client";

import { useMemo, useRef } from "react";
import { format } from "date-fns";
import { useFormatter } from "next-intl";
import { useCalendarStore } from "@/stores/calendarStore";
import { useTimeBlocks, useDeleteTimeBlock, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useTasks, useToggleTaskComplete } from "@/hooks/useTasks";
import { useStudyBlocks, useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useDisciplines } from "@/hooks/useDisciplines";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";
import { useClickToCreate } from "@/hooks/useClickToCreate";
import TimeBlockItem from "./TimeBlockItem";
import ClassBlockItem from "./ClassBlockItem";
import TimeSlot from "./TimeSlot";
import CurrentTimeIndicator from "./CurrentTimeIndicator";
import CreationOverlay from "./CreationOverlay";
import { timeToOffset, HOURS, SLOT_HEIGHT_DAY } from "./calendarUtils";
import { CALENDAR_START_HOUR } from "@/lib/constants";

interface CalendarDayViewProps {
  isDragging?: boolean;
  onCreateRange?: (date: string, startTime: string, endTime: string) => void;
}

export default function CalendarDayView({ isDragging = false, onCreateRange }: CalendarDayViewProps) {
  const fmt = useFormatter();
  const selectedDate = useCalendarStore((s) => s.selectedDate);
  const dateStr = format(selectedDate, "yyyy-MM-dd");
  const isToday = dateStr === format(new Date(), "yyyy-MM-dd");
  const gridRef = useRef<HTMLDivElement>(null);

  const { data: timeBlocks = [] } = useTimeBlocks(dateStr, dateStr);
  const { data: tasks = [] } = useTasks();
  const { data: studyBlocks = [] } = useStudyBlocks();
  const { data: disciplines = [] } = useDisciplines();
  const { data: classOccurrences = [] } = useClassOccurrences(dateStr, dateStr);
  const deleteTimeBlock = useDeleteTimeBlock();
  const updateTimeBlock = useUpdateTimeBlock();
  const toggleComplete = useToggleTaskComplete();
  const updateStudyBlock = useUpdateStudyBlock();

  const { isCreating, creationStart, creationEnd, handlers: clickHandlers } = useClickToCreate({
    slotHeight: SLOT_HEIGHT_DAY,
    startHour: CALENDAR_START_HOUR,
    date: dateStr,
    gridRef,
    disabled: isDragging || !onCreateRange,
    onCreateRange: onCreateRange ?? (() => {}),
  });

  const taskMap = useMemo(() => Object.fromEntries(tasks.map((t) => [t.id, t])), [tasks]);
  const studyBlockMap = useMemo(() => Object.fromEntries(studyBlocks.map((sb) => [sb.id, sb])), [studyBlocks]);
  const disciplineMap = useMemo(() => Object.fromEntries(disciplines.map((d) => [d.id, d])), [disciplines]);

  const handleToggleComplete = (id: string, isCompleted: boolean) => {
    toggleComplete.mutate({ id, is_completed: isCompleted });
  };

  const handleToggleStudyBlockComplete = (id: string, isCompleted: boolean) => {
    updateStudyBlock.mutate({ id, is_completed: isCompleted });
  };

  return (
    <div className="flex-1 overflow-auto">
      <div className="relative flex">
        {/* Time labels */}
        <div className="w-14 shrink-0">
          {HOURS.map((hour) => (
            <div
              key={hour}
              className="relative flex items-start justify-end pr-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-faint)]"
              style={{ height: `${SLOT_HEIGHT_DAY}px` }}
            >
              <span className="relative -top-[5px]">
                {fmt.dateTime(new Date(2000, 0, 1, hour), { hour: "numeric", hour12: true })}
              </span>
            </div>
          ))}
        </div>

        {/* Grid + blocks */}
        <div
          ref={gridRef}
          className="relative flex-1"
          onMouseDown={clickHandlers.onMouseDown}
          onMouseMove={clickHandlers.onMouseMove}
          onMouseUp={clickHandlers.onMouseUp}
        >
          {/* Slots */}
          {HOURS.map((hour) => (
            <div key={hour}>
              <TimeSlot hour={hour} half={0} date={dateStr} height={SLOT_HEIGHT_DAY / 2} />
              <TimeSlot hour={hour} half={1} date={dateStr} height={SLOT_HEIGHT_DAY / 2} />
            </div>
          ))}

          {/* Class occurrences (read-only, dashed) */}
          {classOccurrences.map((occ) => (
            <div
              key={occ.id}
              className="absolute left-0 right-0"
              style={{ top: `${timeToOffset(occ.start_time, SLOT_HEIGHT_DAY)}px` }}
            >
              <ClassBlockItem occurrence={occ} slotHeight={SLOT_HEIGHT_DAY} />
            </div>
          ))}

          {/* Current time indicator */}
          <CurrentTimeIndicator slotHeight={SLOT_HEIGHT_DAY} isToday={isToday} />

          {/* Creation overlay (click-to-create) */}
          {isCreating && creationStart && creationEnd && (
            <CreationOverlay
              startTime={creationStart}
              endTime={creationEnd}
              slotHeight={SLOT_HEIGHT_DAY}
            />
          )}

          {/* Time blocks */}
          {timeBlocks.map((block) => {
            const studyBlock = block.study_block ? studyBlockMap[block.study_block] : undefined;
            const discipline = studyBlock ? disciplineMap[studyBlock.discipline] : undefined;
            return (
              <div
                key={block.id}
                className="absolute left-0 right-0"
                style={{ top: `${timeToOffset(block.start_time, SLOT_HEIGHT_DAY)}px` }}
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
                  slotHeight={SLOT_HEIGHT_DAY}
                />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

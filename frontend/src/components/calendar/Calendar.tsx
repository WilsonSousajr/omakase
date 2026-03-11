"use client";

import { useCalendarStore } from "@/stores/calendarStore";
import CalendarHeader from "./CalendarHeader";
import CalendarDayView from "./CalendarDayView";
import CalendarWeekView from "./CalendarWeekView";

interface CalendarProps {
  isDragging?: boolean;
  onCreateRange?: (date: string, startTime: string, endTime: string) => void;
}

export default function Calendar({ isDragging = false, onCreateRange }: CalendarProps) {
  const { viewMode } = useCalendarStore();

  return (
    <div className="flex h-full flex-col">
      <CalendarHeader />
      {viewMode === "day" ? (
        <CalendarDayView isDragging={isDragging} onCreateRange={onCreateRange} />
      ) : (
        <CalendarWeekView isDragging={isDragging} onCreateRange={onCreateRange} />
      )}
    </div>
  );
}

"use client";

import { useCalendarStore } from "@/stores/calendarStore";
import CalendarHeader from "./CalendarHeader";
import CalendarDayView from "./CalendarDayView";
import CalendarWeekView from "./CalendarWeekView";

export default function Calendar() {
  const { viewMode } = useCalendarStore();

  return (
    <div className="flex h-full flex-col">
      <CalendarHeader />
      {viewMode === "day" ? <CalendarDayView /> : <CalendarWeekView />}
    </div>
  );
}

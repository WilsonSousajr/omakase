"use client";

import { useState, useEffect } from "react";
import { timeToOffset } from "./calendarUtils";
import { CALENDAR_START_HOUR } from "@/lib/constants";

interface CurrentTimeIndicatorProps {
  slotHeight: number;
  isToday: boolean;
  startHour?: number;
}

function getCurrentTimeString(): string {
  const now = new Date();
  return `${now.getHours().toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")}`;
}

export default function CurrentTimeIndicator({
  slotHeight,
  isToday,
  startHour = CALENDAR_START_HOUR,
}: CurrentTimeIndicatorProps) {
  const [currentTime, setCurrentTime] = useState(getCurrentTimeString);

  useEffect(() => {
    if (!isToday) return;
    const interval = setInterval(() => {
      setCurrentTime(getCurrentTimeString());
    }, 60_000);
    return () => clearInterval(interval);
  }, [isToday]);

  if (!isToday) return null;

  const top = timeToOffset(currentTime, slotHeight, startHour);

  return (
    <div
      className="pointer-events-none absolute left-0 right-0 z-20"
      style={{ top: `${top}px` }}
    >
      <div className="relative flex items-center">
        <div
          data-testid="current-time-dot"
          className="absolute -left-1 h-2 w-2 rounded-full bg-red-500"
        />
        <div
          data-testid="current-time-line"
          className="h-[2px] w-full bg-red-500"
        />
      </div>
    </div>
  );
}

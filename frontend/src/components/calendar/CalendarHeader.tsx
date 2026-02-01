"use client";

import { format } from "date-fns";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useCalendarStore } from "@/stores/calendarStore";
import { cn } from "@/lib/utils";

export default function CalendarHeader() {
  const { selectedDate, viewMode, setViewMode, goToToday, goForward, goBack } =
    useCalendarStore();

  return (
    <div className="flex items-center justify-between border-b border-zinc-800 px-4 py-2">
      <div className="flex items-center gap-2">
        <button
          onClick={goBack}
          className="rounded p-1 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        <button
          onClick={goToToday}
          className="rounded px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
        >
          Today
        </button>
        <button
          onClick={goForward}
          className="rounded p-1 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
        <span className="text-sm font-medium text-zinc-200">
          {format(selectedDate, "MMMM d, yyyy")}
        </span>
      </div>

      <div className="flex rounded-md border border-zinc-800">
        {(["day", "week"] as const).map((mode) => (
          <button
            key={mode}
            onClick={() => setViewMode(mode)}
            className={cn(
              "px-3 py-1 text-xs capitalize",
              viewMode === mode
                ? "bg-zinc-800 text-zinc-200"
                : "text-zinc-500 hover:text-zinc-300"
            )}
          >
            {mode}
          </button>
        ))}
      </div>
    </div>
  );
}

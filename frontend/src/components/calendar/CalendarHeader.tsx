"use client";

import { useState, useEffect } from "react";
import { format } from "date-fns";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useCalendarStore } from "@/stores/calendarStore";
import { cn } from "@/lib/utils";

export default function CalendarHeader() {
  const selectedDate = useCalendarStore((s) => s.selectedDate);
  const viewMode = useCalendarStore((s) => s.viewMode);
  const setViewMode = useCalendarStore((s) => s.setViewMode);
  const goToToday = useCalendarStore((s) => s.goToToday);
  const goForward = useCalendarStore((s) => s.goForward);
  const goBack = useCalendarStore((s) => s.goBack);

  const [dateLabel, setDateLabel] = useState("");

  useEffect(() => {
    setDateLabel(format(selectedDate, "MMMM d, yyyy"));
  }, [selectedDate]);

  return (
    <div className="flex items-center justify-between border-b border-[var(--color-border)] px-5 py-3">
      <div className="flex items-center gap-2">
        <button
          onClick={goBack}
          className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        <button
          onClick={goToToday}
          className="rounded-lg px-2 py-0.5 text-xs text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
        >
          Today
        </button>
        <button
          onClick={goForward}
          className="rounded-lg p-1 text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
        <span className="text-sm font-medium text-[var(--color-text-primary)]">
          {dateLabel}
        </span>
      </div>

      <div className="flex rounded-xl border border-[var(--color-border)]">
        {(["day", "week"] as const).map((mode) => (
          <button
            key={mode}
            onClick={() => setViewMode(mode)}
            className={cn(
              "px-3 py-1 text-xs capitalize",
              viewMode === mode
                ? "bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]"
            )}
          >
            {mode}
          </button>
        ))}
      </div>
    </div>
  );
}

import { timeToOffset } from "./calendarUtils";
import { CALENDAR_START_HOUR } from "@/lib/constants";

interface CreationOverlayProps {
  startTime: string;
  endTime: string;
  slotHeight: number;
  startHour?: number;
}

function formatTimeLabel(time: string): string {
  const [h, m] = time.split(":").map(Number);
  const period = h >= 12 ? "PM" : "AM";
  const displayH = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return m === 0 ? `${displayH}:00 ${period}` : `${displayH}:${m.toString().padStart(2, "0")} ${period}`;
}

export default function CreationOverlay({
  startTime,
  endTime,
  slotHeight,
  startHour = CALENDAR_START_HOUR,
}: CreationOverlayProps) {
  const top = timeToOffset(startTime, slotHeight, startHour);
  const bottom = timeToOffset(endTime, slotHeight, startHour);
  const height = bottom - top;

  return (
    <div
      className="pointer-events-none absolute inset-x-1 overflow-hidden rounded-xl border border-white/20 bg-white/10 transition-opacity duration-100"
      style={{ top: `${top}px`, height: `${height}px` }}
    >
      <div className="flex h-full flex-col justify-between px-2 py-1">
        <span className="text-[10px] font-semibold text-[var(--color-text-secondary)]">
          {formatTimeLabel(startTime)}
        </span>
        {height > 20 && (
          <span className="text-[10px] font-semibold text-[var(--color-text-secondary)]">
            {formatTimeLabel(endTime)}
          </span>
        )}
      </div>
    </div>
  );
}

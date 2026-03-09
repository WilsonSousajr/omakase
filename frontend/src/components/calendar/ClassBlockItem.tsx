import { BookOpen, MapPin } from "lucide-react";
import type { ClassOccurrence } from "@/types/classschedule";
import { timeToMinutes } from "./calendarUtils";

interface ClassBlockItemProps {
  occurrence: ClassOccurrence;
  slotHeight: number;
}

export default function ClassBlockItem({ occurrence, slotHeight }: ClassBlockItemProps) {
  const startMin = timeToMinutes(occurrence.start_time);
  const endMin = timeToMinutes(occurrence.end_time);
  const durationSlots = (endMin - startMin) / 30;
  const height = durationSlots * slotHeight;
  const color = occurrence.discipline_color || "#a1a1aa";

  return (
    <div
      className="absolute inset-x-1 overflow-hidden rounded-lg border border-dashed px-2 py-1"
      style={{
        height: `${height}px`,
        borderColor: `${color}50`,
        backgroundColor: `${color}0d`,
      }}
    >
      <div className="flex items-center gap-1.5">
        <BookOpen className="h-3 w-3 shrink-0" style={{ color: `${color}90` }} />
        <p
          className="truncate text-xs font-medium"
          style={{ color: `${color}c0` }}
        >
          {occurrence.discipline_name}
        </p>
        <span
          className="shrink-0 rounded-lg px-1 py-0.5 text-[9px] font-semibold capitalize leading-none"
          style={{
            backgroundColor: `${color}18`,
            color: `${color}90`,
          }}
        >
          {occurrence.class_type}
        </span>
      </div>
      <div className="mt-0.5 flex items-center gap-2">
        <p className="text-[10px]" style={{ color: `${color}70` }}>
          {occurrence.start_time.slice(0, 5)} – {occurrence.end_time.slice(0, 5)}
        </p>
        {occurrence.location && (
          <span className="flex items-center gap-0.5 text-[10px]" style={{ color: `${color}60` }}>
            <MapPin className="h-2.5 w-2.5" />
            {occurrence.location}
          </span>
        )}
      </div>
    </div>
  );
}

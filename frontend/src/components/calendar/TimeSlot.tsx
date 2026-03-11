import { useDroppable } from "@dnd-kit/core";

interface TimeSlotProps {
  hour: number;
  half: 0 | 1;
  date: string;
  height: number;
  onMouseDown?: (e: React.MouseEvent) => void;
}

export default function TimeSlot({ hour, half, date, height, onMouseDown }: TimeSlotProps) {
  const time = `${hour.toString().padStart(2, "0")}:${half === 0 ? "00" : "30"}`;
  const droppableId = `slot-${date}-${time}`;

  const { setNodeRef, isOver } = useDroppable({
    id: droppableId,
    data: { type: "timeslot", date, time },
  });

  return (
    <div
      ref={setNodeRef}
      onMouseDown={onMouseDown}
      className={`transition-colors duration-150 ${
        half === 0
          ? "border-t border-[var(--color-border)]/60"
          : "border-b border-[var(--color-border)]/20"
      } ${isOver ? "bg-white/5" : ""}`}
      style={{ height: `${height}px` }}
    />
  );
}

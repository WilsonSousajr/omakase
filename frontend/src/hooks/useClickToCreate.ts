import { useCallback, useRef, useState } from "react";
import { DRAG_ACTIVATION_DISTANCE, CALENDAR_SNAP_MINUTES, MIN_TIMEBLOCK_MINUTES, CALENDAR_START_HOUR, CALENDAR_END_HOUR } from "@/lib/constants";

interface UseClickToCreateOptions {
  slotHeight: number;
  startHour: number;
  date: string;
  gridRef: React.RefObject<HTMLDivElement | null>;
  disabled?: boolean;
  onCreateRange: (date: string, startTime: string, endTime: string) => void;
}

interface UseClickToCreateReturn {
  isCreating: boolean;
  creationStart: string | null;
  creationEnd: string | null;
  handlers: {
    onMouseDown: (e: React.MouseEvent) => void;
    onMouseMove: (e: React.MouseEvent) => void;
    onMouseUp: (e: React.MouseEvent) => void;
  };
}

function yToMinutes(y: number, slotHeight: number, startHour: number): number {
  const minutesPerPixel = 30 / (slotHeight / 2);
  const rawMinutes = y * minutesPerPixel + startHour * 60;
  return Math.round(rawMinutes / CALENDAR_SNAP_MINUTES) * CALENDAR_SNAP_MINUTES;
}

function minutesToTimeStr(minutes: number): string {
  const clamped = Math.max(CALENDAR_START_HOUR * 60, Math.min(minutes, CALENDAR_END_HOUR * 60));
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}`;
}

function isBlockElement(target: EventTarget): boolean {
  if (!(target instanceof HTMLElement)) return false;
  return !!target.closest("[data-timeblock], [data-classblock]");
}

export function useClickToCreate({
  slotHeight,
  startHour,
  date,
  gridRef,
  disabled = false,
  onCreateRange,
}: UseClickToCreateOptions): UseClickToCreateReturn {
  const [isCreating, setIsCreating] = useState(false);
  const [creationStart, setCreationStart] = useState<string | null>(null);
  const [creationEnd, setCreationEnd] = useState<string | null>(null);

  const anchorY = useRef<number>(0);
  const anchorClientY = useRef<number>(0);
  const isMouseDown = useRef(false);

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      if (disabled || e.button !== 0 || isBlockElement(e.target)) return;
      if (!gridRef.current) return;

      const gridTop = gridRef.current.getBoundingClientRect().top;
      anchorY.current = e.clientY - gridTop;
      anchorClientY.current = e.clientY;
      isMouseDown.current = true;
    },
    [disabled, gridRef],
  );

  const onMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (!isMouseDown.current) return;
      if (!gridRef.current) return;

      const deltaY = Math.abs(e.clientY - anchorClientY.current);

      // Require minimum movement before entering drawing mode
      if (!isCreating && deltaY < DRAG_ACTIVATION_DISTANCE) return;

      const gridTop = gridRef.current.getBoundingClientRect().top;
      const currentY = e.clientY - gridTop;

      const minY = Math.min(anchorY.current, currentY);
      const maxY = Math.max(anchorY.current, currentY);

      const startMin = yToMinutes(minY, slotHeight, startHour);
      const endMin = yToMinutes(maxY, slotHeight, startHour);

      setIsCreating(true);
      setCreationStart(minutesToTimeStr(startMin));
      // Show at least 15 min for visual feedback, but mouseup validates the real range
      setCreationEnd(minutesToTimeStr(endMin <= startMin ? startMin + CALENDAR_SNAP_MINUTES : endMin));
    },
    [isCreating, gridRef, slotHeight, startHour],
  );

  const onMouseUp = useCallback(
    (e: React.MouseEvent) => {
      if (!isMouseDown.current) return;
      isMouseDown.current = false;

      if (isCreating && gridRef.current) {
        const gridTop = gridRef.current.getBoundingClientRect().top;
        const currentY = e.clientY - gridTop;
        const minY = Math.min(anchorY.current, currentY);
        const maxY = Math.max(anchorY.current, currentY);
        const startMin = yToMinutes(minY, slotHeight, startHour);
        const endMin = yToMinutes(maxY, slotHeight, startHour);
        const durationMin = endMin - startMin;

        if (durationMin >= MIN_TIMEBLOCK_MINUTES) {
          onCreateRange(date, minutesToTimeStr(startMin), minutesToTimeStr(endMin));
        }
      }

      setIsCreating(false);
      setCreationStart(null);
      setCreationEnd(null);
    },
    [isCreating, gridRef, slotHeight, startHour, date, onCreateRange],
  );

  return {
    isCreating,
    creationStart,
    creationEnd,
    handlers: { onMouseDown, onMouseMove, onMouseUp },
  };
}

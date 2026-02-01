"use client";

import { useCallback, useRef } from "react";
import type { TimeBlock } from "@/types/timeblock";
import type { Task } from "@/types/task";
import { PRIORITIES } from "@/lib/constants";
import { useDraggable } from "@dnd-kit/core";
import { X } from "lucide-react";

interface TimeBlockItemProps {
  block: TimeBlock;
  task?: Task;
  onDelete: (id: string) => void;
  onResize: (id: string, newEndTime: string) => void;
  slotHeight: number;
}

function timeToMinutes(time: string): number {
  const [h, m] = time.split(":").map(Number);
  return h * 60 + m;
}

function minutesToTime(minutes: number): string {
  const clamped = Math.max(0, Math.min(minutes, 22 * 60));
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:00`;
}

export default function TimeBlockItem({
  block,
  task,
  onDelete,
  onResize,
  slotHeight,
}: TimeBlockItemProps) {
  const startMin = timeToMinutes(block.start_time);
  const endMin = timeToMinutes(block.end_time);
  const durationSlots = (endMin - startMin) / 30;
  const height = durationSlots * slotHeight;

  const priority = task ? PRIORITIES.find((p) => p.value === task.priority) : null;
  const color = priority?.color ?? "#6366f1"; // fallback to indigo

  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: `timeblock-${block.id}`,
    data: { type: "timeblock", block },
  });

  // --- Resize logic via native mouse events ---
  const resizing = useRef(false);
  const startY = useRef(0);
  const startEndMin = useRef(endMin);

  const handleResizeMove = useCallback(
    (e: MouseEvent) => {
      if (!resizing.current) return;
      const deltaY = e.clientY - startY.current;
      // Each slotHeight pixels = 30 minutes
      const deltaMin = Math.round(deltaY / (slotHeight / 2)) * 15;
      const newEnd = Math.max(startMin + 15, startEndMin.current + deltaMin);
      // Clamp to 22:00
      const clamped = Math.min(newEnd, 22 * 60);
      // Update block height visually via style
      const el = document.getElementById(`timeblock-${block.id}`);
      if (el) {
        const newSlots = (clamped - startMin) / 30;
        el.style.height = `${newSlots * slotHeight}px`;
      }
    },
    [block.id, slotHeight, startMin]
  );

  const handleResizeUp = useCallback(
    (e: MouseEvent) => {
      resizing.current = false;
      document.removeEventListener("mousemove", handleResizeMove);
      document.removeEventListener("mouseup", handleResizeUp);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";

      const deltaY = e.clientY - startY.current;
      const deltaMin = Math.round(deltaY / (slotHeight / 2)) * 15;
      const newEnd = Math.max(startMin + 15, startEndMin.current + deltaMin);
      const clamped = Math.min(newEnd, 22 * 60);
      onResize(block.id, minutesToTime(clamped));
    },
    [block.id, handleResizeMove, onResize, slotHeight, startMin]
  );

  const handleResizeDown = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      e.preventDefault();
      resizing.current = true;
      startY.current = e.clientY;
      startEndMin.current = endMin;
      document.body.style.cursor = "ns-resize";
      document.body.style.userSelect = "none";
      document.addEventListener("mousemove", handleResizeMove);
      document.addEventListener("mouseup", handleResizeUp);
    },
    [endMin, handleResizeMove, handleResizeUp]
  );

  const style = {
    height: `${height}px`,
    transform: transform
      ? `translate(${transform.x}px, ${transform.y}px)`
      : undefined,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      id={`timeblock-${block.id}`}
      ref={setNodeRef}
      {...listeners}
      {...attributes}
      className="group absolute inset-x-1 cursor-grab overflow-hidden rounded border px-2 py-1 active:cursor-grabbing"
      style={{
        ...style,
        borderColor: `${color}40`,
        backgroundColor: `${color}18`,
      }}
    >
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <div className="flex items-center gap-1.5">
            <p className="truncate text-xs font-medium" style={{ color }}>
              {task?.title || "Task"}
            </p>
            {priority && (
              <span
                className="shrink-0 rounded px-1 py-0.5 text-[9px] font-semibold leading-none"
                style={{
                  backgroundColor: `${color}25`,
                  color,
                }}
              >
                {priority.label}
              </span>
            )}
          </div>
          <p className="text-[10px]" style={{ color: `${color}90` }}>
            {block.start_time.slice(0, 5)} – {block.end_time.slice(0, 5)}
          </p>
        </div>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onDelete(block.id);
          }}
          className="shrink-0 rounded p-0.5 opacity-0 transition-opacity group-hover:opacity-100"
          style={{ color }}
          onPointerDown={(e) => e.stopPropagation()}
        >
          <X className="h-3 w-3" />
        </button>
      </div>

      {/* Resize handle */}
      <div
        onPointerDown={(e) => e.stopPropagation()}
        onMouseDown={handleResizeDown}
        className="absolute inset-x-0 bottom-0 flex h-2 cursor-ns-resize items-center justify-center opacity-0 transition-opacity group-hover:opacity-100"
      >
        <div
          className="h-0.5 w-8 rounded-full"
          style={{ backgroundColor: `${color}60` }}
        />
      </div>
    </div>
  );
}

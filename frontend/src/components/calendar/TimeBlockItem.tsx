"use client";

import { useCallback, useRef, useState, useEffect } from "react";
import type { TimeBlock } from "@/types/timeblock";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";
import { PRIORITIES } from "@/lib/constants";
import { useDraggable } from "@dnd-kit/core";
import { BookOpen, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { timeToMinutes, minutesToTime } from "./calendarUtils";

interface TimeBlockItemProps {
  block: TimeBlock;
  task?: Task;
  studyBlock?: StudyBlock;
  disciplineColor?: string;
  onDelete: (id: string) => void;
  onResize: (id: string, newEndTime: string) => void;
  onToggleComplete?: (id: string, isCompleted: boolean) => void;
  onToggleStudyBlockComplete?: (id: string, isCompleted: boolean) => void;
  slotHeight: number;
}

export default function TimeBlockItem({
  block,
  task,
  studyBlock,
  disciplineColor,
  onDelete,
  onResize,
  onToggleComplete,
  onToggleStudyBlockComplete,
  slotHeight,
}: TimeBlockItemProps) {
  const startMin = timeToMinutes(block.start_time);
  const endMin = timeToMinutes(block.end_time);
  const durationSlots = (endMin - startMin) / 30;
  const height = durationSlots * slotHeight;

  const isStudyBlock = !!studyBlock;
  const priority = task ? PRIORITIES.find((p) => p.value === task.priority) : null;
  const studyPriority = studyBlock ? PRIORITIES.find((p) => p.value === studyBlock.priority) : null;
  const color = isStudyBlock ? (disciplineColor ?? "#a1a1aa") : (priority?.color ?? "#a1a1aa");
  const title = isStudyBlock ? studyBlock.title : (task?.title || "Task");
  const isCompleted = isStudyBlock ? studyBlock.is_completed : task?.is_completed;

  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: `timeblock-${block.id}`,
    data: { type: "timeblock", block },
  });

  // --- Resize logic via native mouse events ---
  const resizing = useRef(false);
  const startY = useRef(0);
  const startEndMin = useRef(endMin);
  const [resizeHeight, setResizeHeight] = useState<number | null>(null);

  const handleResizeMove = useCallback(
    (e: MouseEvent) => {
      if (!resizing.current) return;
      const deltaY = e.clientY - startY.current;
      const deltaMin = Math.round(deltaY / (slotHeight / 2)) * 15;
      const newEnd = Math.max(startMin + 15, startEndMin.current + deltaMin);
      const clamped = Math.min(newEnd, 22 * 60);
      const newSlots = (clamped - startMin) / 30;
      setResizeHeight(newSlots * slotHeight);
    },
    [slotHeight, startMin]
  );

  const handleResizeUp = useCallback(
    (e: MouseEvent) => {
      resizing.current = false;
      document.removeEventListener("mousemove", handleResizeMove);
      document.removeEventListener("mouseup", handleResizeUp);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
      setResizeHeight(null);

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

  useEffect(() => {
    return () => {
      document.removeEventListener("mousemove", handleResizeMove);
      document.removeEventListener("mouseup", handleResizeUp);
    };
  }, [handleResizeMove, handleResizeUp]);

  const style = {
    height: `${resizeHeight ?? height}px`,
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
      className="group absolute inset-x-1 cursor-grab overflow-hidden rounded-lg border px-2 py-1 active:cursor-grabbing"
      style={{
        ...style,
        borderColor: `${color}40`,
        backgroundColor: `${color}18`,
      }}
    >
      <div className="flex items-start justify-between">
        {/* Checkbox */}
        <button
          onClick={(e) => {
            e.stopPropagation();
            if (isStudyBlock && studyBlock) {
              onToggleStudyBlockComplete?.(studyBlock.id, !studyBlock.is_completed);
            } else if (task?.id) {
              onToggleComplete?.(task.id, !task.is_completed);
            }
          }}
          onPointerDown={(e) => e.stopPropagation()}
          className="mr-1.5 mt-0.5 shrink-0"
        >
          <div className={cn(
            "h-3.5 w-3.5 rounded border transition-all",
            isCompleted
              ? "bg-blue-500 border-blue-500"
              : "border-current opacity-50 hover:opacity-100"
          )}
          style={{ borderColor: color }}
          >
            {isCompleted && (
              <svg className="h-full w-full text-white" viewBox="0 0 16 16">
                <path fill="currentColor" d="M13 4L6 11L3 8" strokeWidth="2.5" stroke="currentColor" />
              </svg>
            )}
          </div>
        </button>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5">
            {isStudyBlock && <BookOpen className="h-3 w-3 shrink-0" style={{ color }} />}
            <p className={cn(
              "truncate text-xs font-medium",
              isCompleted && "line-through opacity-60"
            )}
            style={{ color }}>
              {title}
            </p>
            {priority && !isStudyBlock && (
              <span
                className="shrink-0 rounded-lg px-1 py-0.5 text-[9px] font-semibold leading-none"
                style={{
                  backgroundColor: `${color}25`,
                  color,
                }}
              >
                {priority.label}
              </span>
            )}
            {studyPriority && isStudyBlock && (
              <span
                className="shrink-0 rounded-lg px-1 py-0.5 text-[9px] font-semibold leading-none"
                style={{
                  backgroundColor: `${studyPriority.color}25`,
                  color: studyPriority.color,
                }}
              >
                {studyPriority.label}
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

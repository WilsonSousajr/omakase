"use client";

import {
  DndContext,
  type DragEndEvent,
  type DragOverEvent,
  PointerSensor,
  useSensor,
  useSensors,
  closestCorners,
} from "@dnd-kit/core";
import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { KANBAN_STATUSES, DRAG_ACTIVATION_DISTANCE, type KanbanStatus } from "@/lib/constants";
import { useTodayTasks, useReorderTasks } from "@/hooks/useTasks";
import { useTimeBlocks } from "@/hooks/useTimeBlocks";
import { useToday } from "@/hooks/useToday";
import { useUIStore } from "@/stores/uiStore";
import type { Task } from "@/types/task";
import KanbanColumn from "./KanbanColumn";

const COLUMN_KEYS: Record<string, "todo" | "inProgress" | "done"> = {
  todo: "todo",
  in_progress: "inProgress",
  done: "done",
};

const EMPTY_TASKS: Task[] = [];

export default function KanbanBoard() {
  const t = useTranslations("kanban");
  const today = useToday();
  const { data: serverTasks = EMPTY_TASKS, isLoading } = useTodayTasks(today);
  const reorderTasks = useReorderTasks();
  const { data: timeBlocks } = useTimeBlocks(today, today);
  const setSessionCompletionBlock = useUIStore((s) => s.setSessionCompletionBlock);
  const [tasks, setTasks] = useState<Task[]>([]);
  const isDraggingRef = useRef(false);
  const preDropSnapshotRef = useRef<Task[]>([]);

  useEffect(() => {
    if (!isDraggingRef.current) {
      setTasks(serverTasks);
    }
  }, [serverTasks]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: DRAG_ACTIVATION_DISTANCE } })
  );

  const getTasksByStatus = useCallback(
    (status: KanbanStatus) =>
      tasks.filter((t) => t.kanban_status === status),
    [tasks]
  );

  const handleDragStart = () => {
    isDraggingRef.current = true;
    preDropSnapshotRef.current = [...tasks];
  };

  const handleDragOver = (event: DragOverEvent) => {
    const { active, over } = event;
    if (!over) return;

    const activeTask = tasks.find((t) => t.id === active.id);
    if (!activeTask) return;

    let targetStatus: KanbanStatus | undefined;

    const overData = over.data.current;
    if (overData?.type === "column") {
      targetStatus = overData.status as KanbanStatus;
    } else if (overData?.type === "kanban-card") {
      targetStatus = (overData.task as Task).kanban_status;
    }

    if (targetStatus && activeTask.kanban_status !== targetStatus) {
      setTasks((prev) =>
        prev.map((t) =>
          t.id === activeTask.id ? { ...t, kanban_status: targetStatus } : t
        )
      );
    }
  };

  const handleDragEnd = (event: DragEndEvent) => {
    isDraggingRef.current = false;
    const { active, over } = event;
    if (!over) return;

    // Check if task was moved to "done"
    const draggedTask = tasks.find((t) => t.id === active.id);
    const preDropTask = preDropSnapshotRef.current.find((t) => t.id === active.id);
    const wasMovedToDone =
      draggedTask &&
      preDropTask?.kanban_status !== "done" &&
      draggedTask.kanban_status === "done";

    // Only send tasks from affected columns (source + destination)
    const affectedStatuses = new Set<KanbanStatus>();
    if (preDropTask) affectedStatuses.add(preDropTask.kanban_status);
    if (draggedTask) affectedStatuses.add(draggedTask.kanban_status);

    const reorderItems = tasks
      .filter((t) => affectedStatuses.has(t.kanban_status))
      .map((t, i) => ({
        id: t.id,
        kanban_order: i,
        kanban_status: t.kanban_status,
      }));

    const rollback = preDropSnapshotRef.current;
    reorderTasks.mutate(reorderItems, {
      onError: () => setTasks(rollback),
    });

    // Trigger session completion if moved to done
    if (wasMovedToDone && timeBlocks) {
      const unratedBlock = timeBlocks.find(
        (b) => b.task === active.id && b.session_rating == null
      );
      if (unratedBlock) {
        setSessionCompletionBlock(unratedBlock);
      }
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-full gap-5 p-5">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="flex-1 animate-pulse rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)]/50"
          />
        ))}
      </div>
    );
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
    >
      <div className="flex h-full gap-5 p-5">
        {KANBAN_STATUSES.map(({ value }) => (
          <KanbanColumn
            key={value}
            status={value}
            label={t(COLUMN_KEYS[value])}
            tasks={getTasksByStatus(value)}
          />
        ))}
      </div>
    </DndContext>
  );
}

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
import { KANBAN_STATUSES, DRAG_ACTIVATION_DISTANCE, type KanbanStatus } from "@/lib/constants";
import { useTodayTasks, useReorderTasks } from "@/hooks/useTasks";
import type { Task } from "@/types/task";
import KanbanColumn from "./KanbanColumn";

const EMPTY_TASKS: Task[] = [];

export default function KanbanBoard() {
  const { data: serverTasks = EMPTY_TASKS, isLoading } = useTodayTasks();
  const reorderTasks = useReorderTasks();
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
    const { over } = event;
    if (!over) return;

    const reorderItems = tasks.map((t, i) => ({
      id: t.id,
      kanban_order: i,
      kanban_status: t.kanban_status,
    }));

    const rollback = preDropSnapshotRef.current;
    reorderTasks.mutate(reorderItems, {
      onError: () => setTasks(rollback),
    });
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
        {KANBAN_STATUSES.map(({ value, label }) => (
          <KanbanColumn
            key={value}
            status={value}
            label={label}
            tasks={getTasksByStatus(value)}
          />
        ))}
      </div>
    </DndContext>
  );
}

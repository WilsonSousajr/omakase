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
import { useCallback, useEffect, useState } from "react";
import { KANBAN_STATUSES, type KanbanStatus } from "@/lib/constants";
import { useTodayTasks, useReorderTasks, useUpdateTask } from "@/hooks/useTasks";
import type { Task } from "@/types/task";
import KanbanColumn from "./KanbanColumn";

export default function KanbanBoard() {
  const { data: serverTasks = [], isLoading } = useTodayTasks();
  const reorderTasks = useReorderTasks();
  const updateTask = useUpdateTask();
  const [tasks, setTasks] = useState<Task[]>([]);

  useEffect(() => {
    setTasks(serverTasks);
  }, [serverTasks]);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  );

  const getTasksByStatus = useCallback(
    (status: KanbanStatus) =>
      tasks.filter((t) => t.kanban_status === status),
    [tasks]
  );

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
    const { active, over } = event;
    if (!over) return;

    const reorderItems = tasks.map((t, i) => ({
      id: t.id,
      kanban_order: i,
      kanban_status: t.kanban_status,
    }));

    reorderTasks.mutate(reorderItems);

    // Also update the specific task's status in case it moved columns
    const movedTask = tasks.find((t) => t.id === active.id);
    const originalTask = serverTasks.find((t) => t.id === active.id);
    if (movedTask && originalTask && movedTask.kanban_status !== originalTask.kanban_status) {
      updateTask.mutate({
        id: movedTask.id,
        kanban_status: movedTask.kanban_status,
      });
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-full gap-4 p-4">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="flex-1 animate-pulse rounded-xl border border-zinc-800 bg-zinc-950/50"
          />
        ))}
      </div>
    );
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
    >
      <div className="flex h-full gap-4 p-4">
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

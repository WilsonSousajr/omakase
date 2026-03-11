"use client";

import { useDraggable } from "@dnd-kit/core";
import type { Task } from "@/types/task";
import TaskCard from "./TaskCard";

interface DraggableTaskCardProps {
  task: Task;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
  onToggleComplete: (id: string, isCompleted: boolean) => void;
}

export default function DraggableTaskCard({
  task,
  onEdit,
  onDelete,
  onToggleComplete,
}: DraggableTaskCardProps) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: `task-${task.id}`,
    data: { type: "task", task },
  });

  return (
    <div
      ref={setNodeRef}
      style={{
        opacity: isDragging ? 0 : 1,
        cursor: isDragging ? "grabbing" : "grab",
      }}
      {...listeners}
      {...attributes}
    >
      <TaskCard
        task={task}
        onEdit={onEdit}
        onDelete={onDelete}
        onToggleComplete={onToggleComplete}
      />
    </div>
  );
}

"use client";

import { useState } from "react";
import { useTasks, useDeleteTask, useToggleTaskComplete } from "@/hooks/useTasks";
import { useUIStore } from "@/stores/uiStore";
import DraggableTaskCard from "./DraggableTaskCard";
import TaskFilters from "./TaskFilters";
import TaskForm from "./TaskForm";
import type { Task } from "@/types/task";

export default function TaskList() {
  const [search, setSearch] = useState("");
  const [priority, setPriority] = useState("");
  const [editTask, setEditTask] = useState<Task | null>(null);
  const { openModal, closeModal } = useUIStore();
  const deleteTask = useDeleteTask();
  const toggleComplete = useToggleTaskComplete();

  const { data: tasks = [], isLoading } = useTasks({
    priority: priority || undefined,
    search: search || undefined,
  });

  const handleEdit = (task: Task) => {
    setEditTask(task);
    openModal("task-form");
  };

  const handleDelete = (id: string) => {
    deleteTask.mutate(id);
  };

  const handleToggleComplete = (id: string, isCompleted: boolean) => {
    toggleComplete.mutate({ id, is_completed: isCompleted });
  };

  const handleCloseForm = () => {
    setEditTask(null);
    closeModal();
  };

  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-zinc-800 p-3">
        <TaskFilters
          search={search}
          onSearchChange={setSearch}
          priority={priority}
          onPriorityChange={setPriority}
        />
      </div>

      <div className="flex-1 space-y-2 overflow-auto p-3">
        {isLoading ? (
          <div className="space-y-2">
            {[1, 2, 3].map((i) => (
              <div
                key={i}
                className="h-20 animate-pulse rounded-lg border border-zinc-800 bg-zinc-900"
              />
            ))}
          </div>
        ) : tasks.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-zinc-500">
            <p className="text-sm">No tasks yet</p>
            <p className="text-xs">Click &quot;New Task&quot; to get started</p>
          </div>
        ) : (
          tasks.map((task) => (
            <DraggableTaskCard
              key={task.id}
              task={task}
              onEdit={handleEdit}
              onDelete={handleDelete}
              onToggleComplete={handleToggleComplete}
            />
          ))
        )}
      </div>

      <TaskForm editTask={editTask} onClose={handleCloseForm} />
    </div>
  );
}

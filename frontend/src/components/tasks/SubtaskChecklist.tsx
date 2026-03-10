"use client";

import { useState } from "react";
import { X, Plus } from "lucide-react";
import {
  useSubtasks,
  useCreateSubtask,
  useUpdateSubtask,
  useDeleteSubtask,
} from "@/hooks/useSubtasks";

interface SubtaskChecklistProps {
  taskId: string;
}

export default function SubtaskChecklist({ taskId }: SubtaskChecklistProps) {
  const { data: subtasks = [], isLoading } = useSubtasks(taskId);
  const createSubtask = useCreateSubtask(taskId);
  const updateSubtask = useUpdateSubtask(taskId);
  const deleteSubtask = useDeleteSubtask(taskId);
  const [newTitle, setNewTitle] = useState("");

  const completedCount = subtasks.filter((s) => s.is_completed).length;
  const totalCount = subtasks.length;

  const handleToggle = (id: string, currentState: boolean) => {
    updateSubtask.mutate({ id, is_completed: !currentState });
  };

  const handleAdd = () => {
    const trimmed = newTitle.trim();
    if (!trimmed) return;
    createSubtask.mutate({ title: trimmed });
    setNewTitle("");
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleAdd();
    }
  };

  const handleDelete = (id: string) => {
    deleteSubtask.mutate(id);
  };

  if (isLoading) {
    return (
      <div className="py-2">
        <p className="text-xs text-[var(--color-text-faint)]">
          Loading subtasks...
        </p>
      </div>
    );
  }

  return (
    <div>
      <div className="mb-2 flex items-center gap-2">
        <h4 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          Subtasks
        </h4>
        {totalCount > 0 && (
          <span className="text-[10px] font-medium text-[var(--color-text-faint)]">
            {completedCount}/{totalCount}
          </span>
        )}
      </div>

      <div className="space-y-1">
        {subtasks.map((subtask) => (
          <div
            key={subtask.id}
            className="group flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-white/5"
          >
            <input
              type="checkbox"
              checked={subtask.is_completed}
              onChange={() => handleToggle(subtask.id, subtask.is_completed)}
              className="h-3.5 w-3.5 shrink-0 cursor-pointer rounded border-[var(--color-border)] bg-transparent accent-[var(--color-text-secondary)]"
            />
            <span
              className={`flex-1 text-xs ${
                subtask.is_completed
                  ? "text-[var(--color-text-faint)] line-through"
                  : "text-[var(--color-text-primary)]"
              }`}
            >
              {subtask.title}
            </span>
            <button
              type="button"
              onClick={() => handleDelete(subtask.id)}
              aria-label="Delete subtask"
              className="shrink-0 rounded p-0.5 text-[var(--color-text-faint)] opacity-0 transition-opacity hover:text-[var(--color-text-secondary)] group-hover:opacity-100"
            >
              <X className="h-3 w-3" />
            </button>
          </div>
        ))}
      </div>

      <div className="mt-1.5 flex items-center gap-2 rounded-lg px-2 py-1.5">
        <Plus className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-faint)]" />
        <input
          type="text"
          placeholder="Add subtask..."
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          onKeyDown={handleKeyDown}
          className="flex-1 bg-transparent text-xs text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] outline-none"
        />
      </div>
    </div>
  );
}

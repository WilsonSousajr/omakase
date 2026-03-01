"use client";

import { useUIStore } from "@/stores/uiStore";
import { useTask } from "@/hooks/useTasks";
import PomodoroTimer from "./PomodoroTimer";
import MarkdownEditor from "./MarkdownEditor";

export default function ActiveTaskPanel() {
  const activeTaskId = useUIStore((s) => s.activeTaskId);
  const { data: task } = useTask(activeTaskId);

  return (
    <div className="flex h-full flex-col gap-5 overflow-auto p-5">
      <PomodoroTimer />

      {task ? (
        <>
          <div className="border-t border-[var(--color-border)] pt-4">
            <h3 className="mb-1 text-sm font-medium text-[var(--color-text-primary)]">
              {task.title}
            </h3>
            {task.description && (
              <p className="text-xs text-[var(--color-text-muted)]">{task.description}</p>
            )}
          </div>

          <div>
            <h4 className="mb-2 text-xs font-medium text-[var(--color-text-secondary)]">Notes</h4>
            <MarkdownEditor taskId={task.id} initialContent={task.notes || ""} />
          </div>
        </>
      ) : (
        <div className="flex flex-col items-center justify-center py-8 text-[var(--color-text-faint)]">
          <p className="text-xs">Select a task from the kanban board</p>
        </div>
      )}
    </div>
  );
}

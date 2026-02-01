"use client";

import { useUIStore } from "@/stores/uiStore";
import { useTask } from "@/hooks/useTasks";
import PomodoroTimer from "./PomodoroTimer";
import MarkdownEditor from "./MarkdownEditor";

export default function ActiveTaskPanel() {
  const { activeTaskId } = useUIStore();
  const { data: task } = useTask(activeTaskId);

  return (
    <div className="flex h-full flex-col gap-4 overflow-auto p-4">
      <PomodoroTimer />

      {task ? (
        <>
          <div className="border-t border-zinc-800 pt-4">
            <h3 className="mb-1 text-sm font-medium text-zinc-200">
              {task.title}
            </h3>
            {task.description && (
              <p className="text-xs text-zinc-500">{task.description}</p>
            )}
          </div>

          <div>
            <h4 className="mb-2 text-xs font-medium text-zinc-400">Notes</h4>
            <MarkdownEditor taskId={task.id} initialContent={task.notes || ""} />
          </div>
        </>
      ) : (
        <div className="flex flex-col items-center justify-center py-8 text-zinc-600">
          <p className="text-xs">Select a task from the kanban board</p>
        </div>
      )}
    </div>
  );
}

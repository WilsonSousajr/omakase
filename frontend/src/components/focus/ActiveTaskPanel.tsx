"use client";

import { useRef, useEffect, useCallback, useMemo } from "react";
import { useTranslations } from "next-intl";
import { useUIStore } from "@/stores/uiStore";
import { useTask } from "@/hooks/useTasks";
import { useTimeBlocks, useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import { useToday } from "@/hooks/useToday";
import { NOTES_DEBOUNCE_MS } from "@/lib/constants";
import PomodoroTimer from "./PomodoroTimer";
import MarkdownEditor from "./MarkdownEditor";
import SubtaskChecklist from "@/components/tasks/SubtaskChecklist";

export default function ActiveTaskPanel() {
  const t = useTranslations("pomodoro");
  const tTasks = useTranslations("tasks");
  const tFocus = useTranslations("focus");
  const activeTaskId = useUIStore((s) => s.activeTaskId);
  const { data: task } = useTask(activeTaskId);
  const today = useToday();
  const { data: timeBlocks } = useTimeBlocks(today, today);
  const updateTimeBlock = useUpdateTimeBlock();
  const sessionNotesRef = useRef<string>("");
  const debounceRef = useRef<NodeJS.Timeout>(undefined);

  // Find current session's time block
  const currentTimeBlock = useMemo(() => {
    if (!timeBlocks || !activeTaskId) return null;
    const taskBlocks = timeBlocks.filter((b) => b.task === activeTaskId);
    if (taskBlocks.length === 0) return null;
    // Return the most recent one (last by start_time)
    return taskBlocks.sort((a, b) => a.start_time.localeCompare(b.start_time)).at(-1) || null;
  }, [timeBlocks, activeTaskId]);

  // Sync ref when time block changes
  useEffect(() => {
    if (currentTimeBlock) {
      sessionNotesRef.current = currentTimeBlock.notes || "";
    }
  }, [currentTimeBlock?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSessionNotesChange = useCallback(
    (value: string) => {
      sessionNotesRef.current = value;
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => {
        if (currentTimeBlock) {
          updateTimeBlock.mutate({ id: currentTimeBlock.id, notes: value });
        }
      }, NOTES_DEBOUNCE_MS);
    },
    [currentTimeBlock, updateTimeBlock],
  );

  // Cleanup debounce
  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

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

          <SubtaskChecklist taskId={task.id} />

          <div>
            <h4 className="mb-2 text-xs font-medium text-[var(--color-text-secondary)]">{tTasks("notes")}</h4>
            <MarkdownEditor taskId={task.id} initialContent={task.notes || ""} />
          </div>

          {currentTimeBlock && (
            <div>
              <h4 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-secondary)]">
                {tFocus("sessionNotes")}
              </h4>
              <textarea
                defaultValue={currentTimeBlock.notes || ""}
                onChange={(e) => handleSessionNotesChange(e.target.value)}
                key={currentTimeBlock.id}
                placeholder={tFocus("sessionNotesPlaceholder")}
                className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] focus:border-[var(--color-border-hover)] focus:outline-none"
                rows={3}
              />
            </div>
          )}
        </>
      ) : (
        <div className="flex flex-col items-center justify-center py-8 text-[var(--color-text-faint)]">
          <p className="text-xs">{t("selectTask")}</p>
        </div>
      )}
    </div>
  );
}

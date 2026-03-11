"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";
import { PRIORITIES, AREAS } from "@/lib/constants";
import { useTags } from "@/hooks/useTags";
import { useProjects } from "@/hooks/useProjects";
import { useDisciplines } from "@/hooks/useDisciplines";
import { useCreateTask, useUpdateTask } from "@/hooks/useTasks";
import { useCreateTimeBlock } from "@/hooks/useTimeBlocks";
import { useUIStore } from "@/stores/uiStore";
import { useCalendarStore } from "@/stores/calendarStore";
import SubtaskChecklist from "./SubtaskChecklist";
import type { Priority, Area } from "@/lib/constants";

export default function TaskForm() {
  const modalOpen = useUIStore((s) => s.modalOpen);
  const editTask = useUIStore((s) => s.editTask);
  const setEditTask = useUIStore((s) => s.setEditTask);
  const closeModal = useUIStore((s) => s.closeModal);
  const { data: tags = [] } = useTags();
  const { data: projects = [] } = useProjects();
  const { data: disciplines = [] } = useDisciplines();
  const createTask = useCreateTask();
  const updateTask = useUpdateTask();
  const t = useTranslations("tasks");
  const tc = useTranslations("constants");
  const tCommon = useTranslations("common");
  const createTimeBlock = useCreateTimeBlock();
  const creationDraft = useCalendarStore((s) => s.creationDraft);
  const clearCreationDraft = useCalendarStore((s) => s.clearCreationDraft);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<Priority>("medium");
  const [area, setArea] = useState<Area>("work");
  const [projectId, setProjectId] = useState<string>("");
  const [disciplineId, setDisciplineId] = useState<string>("");
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [scheduledDate, setScheduledDate] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [estimatedMinutes, setEstimatedMinutes] = useState("");
  const lastInitId = useRef<string | null>(null);

  useEffect(() => {
    if (editTask && editTask.id !== lastInitId.current) {
      lastInitId.current = editTask.id;
      setTitle(editTask.title);
      setDescription(editTask.description || "");
      setPriority(editTask.priority);
      setArea(editTask.area);
      setProjectId(editTask.project || "");
      setDisciplineId(editTask.discipline || "");
      setSelectedTagIds(editTask.tags.map((t) => t.id));
      setScheduledDate(editTask.scheduled_date || "");
      setDueDate(editTask.due_date || "");
      setEstimatedMinutes(editTask.estimated_minutes?.toString() || "");
    } else if (!editTask && lastInitId.current !== null) {
      lastInitId.current = null;
      setTitle("");
      setDescription("");
      setPriority("medium");
      setArea("work");
      setProjectId("");
      setDisciplineId("");
      setSelectedTagIds([]);
      setScheduledDate(creationDraft?.date ?? "");
      setDueDate("");
      setEstimatedMinutes("");
    }
  }, [editTask, creationDraft]);

  if (modalOpen !== "task-form") return null;

  const handleClose = () => {
    setEditTask(null);
    clearCreationDraft();
    closeModal();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const payload = {
      title: title.trim(),
      description,
      priority,
      area,
      tag_ids: selectedTagIds,
      project: area === "study" ? null : (projectId || null),
      discipline: area === "study" ? (disciplineId || null) : null,
      scheduled_date: scheduledDate || null,
      due_date: dueDate || null,
      estimated_minutes: estimatedMinutes ? parseInt(estimatedMinutes) : null,
    };

    if (editTask) {
      await updateTask.mutateAsync({ id: editTask.id, ...payload });
    } else {
      const newTask = await createTask.mutateAsync(payload);
      // If opened via click-to-create, also create a TimeBlock with the drawn times
      if (creationDraft) {
        try {
          await createTimeBlock.mutateAsync({
            task: newTask.id,
            date: creationDraft.date,
            start_time: creationDraft.startTime + ":00",
            end_time: creationDraft.endTime + ":00",
          });
        } catch {
          // TimeBlock creation failed but task was created — acceptable degradation
        }
      }
    }
    clearCreationDraft();
    handleClose();
  };

  const toggleTag = (id: string) => {
    setSelectedTagIds((prev) =>
      prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editTask ? t("editTask") : t("newTask")}
          </h3>
          <button
            onClick={handleClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-6">
          <div>
            <input
              type="text"
              placeholder={t("titlePlaceholder")}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              autoFocus
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div>
            <textarea
              placeholder={t("descriptionPlaceholder")}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("priority")}</label>
              <select
                value={priority}
                onChange={(e) => setPriority(e.target.value as Priority)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {PRIORITIES.map((p) => (
                  <option key={p.value} value={p.value}>
                    {tc(`priorities.${p.value}`)}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("area")}</label>
              <select
                value={area}
                onChange={(e) => setArea(e.target.value as Area)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {AREAS.map((a) => (
                  <option key={a.value} value={a.value}>
                    {tc(`areas.${a.value}`)}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              {area === "study" ? (
                <>
                  <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("discipline")}</label>
                  <select
                    value={disciplineId}
                    onChange={(e) => setDisciplineId(e.target.value)}
                    className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
                  >
                    <option value="">{t("none")}</option>
                    {disciplines.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </>
              ) : (
                <>
                  <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("project")}</label>
                  <select
                    value={projectId}
                    onChange={(e) => setProjectId(e.target.value)}
                    className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
                  >
                    <option value="">{t("none")}</option>
                    {projects.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                </>
              )}
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("scheduledDate")}</label>
              <input
                type="date"
                value={scheduledDate}
                onChange={(e) => setScheduledDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("dueDate")}</label>
              <input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="w-24">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("estimatedMinutes")}</label>
              <input
                type="number"
                min="0"
                max="1440"
                value={estimatedMinutes}
                onChange={(e) => setEstimatedMinutes(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
          </div>

          {tags.length > 0 && (
            <div>
              <label className="mb-1.5 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">{t("tags")}</label>
              <div className="flex flex-wrap gap-1.5">
                {tags.map((tag) => (
                  <button
                    key={tag.id}
                    type="button"
                    onClick={() => toggleTag(tag.id)}
                    className="rounded-lg px-2.5 py-1 text-xs transition-colors"
                    style={{
                      backgroundColor: selectedTagIds.includes(tag.id)
                        ? tag.color + "30"
                        : "transparent",
                      color: selectedTagIds.includes(tag.id)
                        ? tag.color
                        : "var(--color-text-secondary)",
                      border: `1px solid ${
                        selectedTagIds.includes(tag.id)
                          ? tag.color + "60"
                          : "var(--color-border)"
                      }`,
                    }}
                  >
                    {tag.name}
                  </button>
                ))}
              </div>
            </div>
          )}

          {editTask && (
            <SubtaskChecklist taskId={editTask.id} />
          )}

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={handleClose}
              className="rounded-xl px-3 py-1.5 text-xs text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]"
            >
              {tCommon("cancel")}
            </button>
            <button
              type="submit"
              disabled={!title.trim() || createTask.isPending || updateTask.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editTask ? tCommon("update") : tCommon("create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

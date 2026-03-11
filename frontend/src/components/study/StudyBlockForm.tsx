"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";
import { PRIORITIES, STUDY_BLOCK_TYPES, STUDY_BLOCK_STATUSES } from "@/lib/constants";
import { useDisciplines } from "@/hooks/useDisciplines";
import { useCreateStudyBlock, useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import { useUIStore } from "@/stores/uiStore";
import type { StudyBlock } from "@/types/studyblock";
import type { Priority, StudyBlockType, StudyBlockStatus } from "@/lib/constants";

interface StudyBlockFormProps {
  editStudyBlock?: StudyBlock | null;
  defaultDisciplineId?: string | null;
  onClose: () => void;
}

export default function StudyBlockForm({ editStudyBlock, defaultDisciplineId, onClose }: StudyBlockFormProps) {
  const t = useTranslations("study");
  const tc = useTranslations("constants");
  const tco = useTranslations("common");
  const modalOpen = useUIStore((s) => s.modalOpen);
  const { data: disciplines = [] } = useDisciplines();
  const createStudyBlock = useCreateStudyBlock();
  const updateStudyBlock = useUpdateStudyBlock();

  const [title, setTitle] = useState("");
  const [disciplineId, setDisciplineId] = useState("");
  const [blockType, setBlockType] = useState<StudyBlockType>("theory");
  const [priority, setPriority] = useState<Priority>("medium");
  const [status, setStatus] = useState<StudyBlockStatus>("planned");
  const [notes, setNotes] = useState("");
  const [estimatedMinutes, setEstimatedMinutes] = useState("");
  const [scheduledDate, setScheduledDate] = useState("");
  const [dueDate, setDueDate] = useState("");
  const defaultsInitialized = useRef(false);

  useEffect(() => {
    if (editStudyBlock) {
      setTitle(editStudyBlock.title);
      setDisciplineId(editStudyBlock.discipline);
      setBlockType(editStudyBlock.block_type);
      setPriority(editStudyBlock.priority);
      setStatus(editStudyBlock.status);
      setNotes(editStudyBlock.notes || "");
      setEstimatedMinutes(editStudyBlock.estimated_minutes?.toString() || "");
      setScheduledDate(editStudyBlock.scheduled_date || "");
      setDueDate(editStudyBlock.due_date || "");
      defaultsInitialized.current = true;
    } else {
      defaultsInitialized.current = false;
      const defaultId = defaultDisciplineId || disciplines[0]?.id || "";
      if (defaultId) {
        setDisciplineId(defaultId);
        defaultsInitialized.current = true;
      }
    }
  }, [editStudyBlock, disciplines, defaultDisciplineId]);

  if (modalOpen !== "studyblock-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !disciplineId) return;

    const payload = {
      title: title.trim(),
      discipline: disciplineId,
      block_type: blockType,
      priority,
      status,
      notes,
      estimated_minutes: estimatedMinutes ? parseInt(estimatedMinutes) : null,
      scheduled_date: scheduledDate || null,
      due_date: dueDate || null,
    };

    if (editStudyBlock) {
      await updateStudyBlock.mutateAsync({ id: editStudyBlock.id, ...payload });
    } else {
      await createStudyBlock.mutateAsync(payload);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editStudyBlock ? t("editStudyBlock") : t("newStudyBlock")}
          </h3>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-6">
          <div>
            <input
              type="text"
              placeholder={t("blockTitleFormPlaceholder")}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              autoFocus
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div>
            <textarea
              placeholder={t("notesPlaceholder")}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("discipline")}
              </label>
              <select
                value={disciplineId}
                onChange={(e) => setDisciplineId(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                <option value="">{t("selectDiscipline")}</option>
                {disciplines.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}{d.code ? ` (${d.code})` : ""}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("type")}
              </label>
              <select
                value={blockType}
                onChange={(e) => setBlockType(e.target.value as StudyBlockType)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {STUDY_BLOCK_TYPES.map((sbt) => (
                  <option key={sbt.value} value={sbt.value}>
                    {tc(`studyBlockTypes.${sbt.value}`)}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("priority")}
              </label>
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
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("blockStatus")}
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as StudyBlockStatus)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {STUDY_BLOCK_STATUSES.map((s) => (
                  <option key={s.value} value={s.value}>
                    {tc(`studyBlockStatuses.${s.value}`)}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("scheduledDate")}
              </label>
              <input
                type="date"
                value={scheduledDate}
                onChange={(e) => setScheduledDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("dueDate")}
              </label>
              <input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="w-24">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("estimatedMinutes")}
              </label>
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

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl px-3 py-1.5 text-xs text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]"
            >
              {tco("cancel")}
            </button>
            <button
              type="submit"
              disabled={!title.trim() || !disciplineId || createStudyBlock.isPending || updateStudyBlock.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editStudyBlock ? tco("update") : tco("create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

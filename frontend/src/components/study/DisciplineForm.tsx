"use client";

import { useState, useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";
import { DISCIPLINE_STATUSES } from "@/lib/constants";
import ColorSwatchPicker from "@/components/ColorSwatchPicker";
import { useSemesters } from "@/hooks/useSemesters";
import { useCreateDiscipline, useUpdateDiscipline } from "@/hooks/useDisciplines";
import { useUIStore } from "@/stores/uiStore";
import type { Discipline } from "@/types/discipline";
import type { DisciplineStatus } from "@/lib/constants";

interface DisciplineFormProps {
  editDiscipline?: Discipline | null;
  defaultSemesterId?: string | null;
  onClose: () => void;
}

export default function DisciplineForm({ editDiscipline, defaultSemesterId, onClose }: DisciplineFormProps) {
  const t = useTranslations("study");
  const tc = useTranslations("constants");
  const tco = useTranslations("common");
  const modalOpen = useUIStore((s) => s.modalOpen);
  const { data: semesters = [] } = useSemesters();
  const createDiscipline = useCreateDiscipline();
  const updateDiscipline = useUpdateDiscipline();

  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [professor, setProfessor] = useState("");
  const [semesterId, setSemesterId] = useState("");
  const [color, setColor] = useState("#a3a3a3");
  const [credits, setCredits] = useState("");
  const [targetGrade, setTargetGrade] = useState("");
  const [status, setStatus] = useState<DisciplineStatus>("active");
  const defaultsInitialized = useRef(false);

  useEffect(() => {
    if (editDiscipline) {
      setName(editDiscipline.name);
      setCode(editDiscipline.code || "");
      setProfessor(editDiscipline.professor || "");
      setSemesterId(editDiscipline.semester);
      setColor(editDiscipline.color);
      setCredits(editDiscipline.credits?.toString() || "");
      setTargetGrade(editDiscipline.target_grade?.toString() || "");
      setStatus(editDiscipline.status);
      defaultsInitialized.current = true;
    } else {
      defaultsInitialized.current = false;
      const defaultId = defaultSemesterId || semesters[0]?.id || "";
      if (defaultId) {
        setSemesterId(defaultId);
        defaultsInitialized.current = true;
      }
    }
  }, [editDiscipline, semesters, defaultSemesterId]);

  if (modalOpen !== "discipline-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !semesterId) return;

    const payload = {
      name: name.trim(),
      code,
      professor,
      semester: semesterId,
      color,
      credits: credits ? parseInt(credits) : null,
      target_grade: targetGrade ? parseFloat(targetGrade) : null,
      status,
    };

    if (editDiscipline) {
      await updateDiscipline.mutateAsync({ id: editDiscipline.id, ...payload });
    } else {
      await createDiscipline.mutateAsync(payload);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editDiscipline ? t("editDiscipline") : t("newDiscipline")}
          </h3>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-6">
          <div className="flex gap-3">
            <div className="flex-1">
              <input
                type="text"
                placeholder={t("disciplineNameFormPlaceholder")}
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoFocus
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="w-28">
              <input
                type="text"
                placeholder={t("code")}
                value={code}
                onChange={(e) => setCode(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
          </div>

          <div>
            <input
              type="text"
              placeholder={t("professorFormPlaceholder")}
              value={professor}
              onChange={(e) => setProfessor(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("semester")}
              </label>
              <select
                value={semesterId}
                onChange={(e) => setSemesterId(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                <option value="">{t("selectSemester")}</option>
                {semesters.map((sem) => (
                  <option key={sem.id} value={sem.id}>
                    {sem.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("status")}
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as DisciplineStatus)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {DISCIPLINE_STATUSES.map((s) => (
                  <option key={s.value} value={s.value}>
                    {tc(`disciplineStatuses.${s.value}`)}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <ColorSwatchPicker value={color} onChange={setColor} />

          <div className="w-24">
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {t("credits")}
            </label>
            <input
              type="number"
              value={credits}
              onChange={(e) => setCredits(e.target.value)}
              placeholder="0"
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
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
              disabled={!name.trim() || !semesterId || createDiscipline.isPending || updateDiscipline.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editDiscipline ? tco("update") : tco("create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

"use client";

import { useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";
import { SEMESTER_STATUSES } from "@/lib/constants";
import { useCreateSemester, useUpdateSemester } from "@/hooks/useSemesters";
import { useUIStore } from "@/stores/uiStore";
import type { Semester } from "@/types/semester";
import type { SemesterStatus } from "@/lib/constants";

interface SemesterFormProps {
  editSemester?: Semester | null;
  onClose: () => void;
}

export default function SemesterForm({ editSemester, onClose }: SemesterFormProps) {
  const t = useTranslations("study");
  const tc = useTranslations("constants");
  const tco = useTranslations("common");
  const modalOpen = useUIStore((s) => s.modalOpen);
  const createSemester = useCreateSemester();
  const updateSemester = useUpdateSemester();

  const [name, setName] = useState("");
  const [institution, setInstitution] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [status, setStatus] = useState<SemesterStatus>("active");

  useEffect(() => {
    if (editSemester) {
      setName(editSemester.name);
      setInstitution(editSemester.institution || "");
      setStartDate(editSemester.start_date);
      setEndDate(editSemester.end_date);
      setStatus(editSemester.status);
    } else {
      setName("");
      setInstitution("");
      setStartDate("");
      setEndDate("");
      setStatus("active");
    }
  }, [editSemester]);

  if (modalOpen !== "semester-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !startDate || !endDate) return;

    const payload = {
      name: name.trim(),
      institution,
      start_date: startDate,
      end_date: endDate,
      status,
    };

    if (editSemester) {
      await updateSemester.mutateAsync({ id: editSemester.id, ...payload });
    } else {
      await createSemester.mutateAsync(payload);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editSemester ? t("editSemester") : t("newSemester")}
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
              placeholder={t("semesterNameFormPlaceholder")}
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div>
            <input
              type="text"
              placeholder={t("institutionFormPlaceholder")}
              value={institution}
              onChange={(e) => setInstitution(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("startDate")}
              </label>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("endDate")}
              </label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {t("status")}
            </label>
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value as SemesterStatus)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
            >
              {SEMESTER_STATUSES.map((s) => (
                <option key={s.value} value={s.value}>
                  {tc(`semesterStatuses.${s.value}`)}
                </option>
              ))}
            </select>
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
              disabled={!name.trim() || !startDate || !endDate || createSemester.isPending || updateSemester.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editSemester ? tco("update") : tco("create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

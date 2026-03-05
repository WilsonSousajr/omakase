"use client";

import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { CLASS_TYPES, DAYS_OF_WEEK } from "@/lib/constants";
import { useCreateClassSchedule, useUpdateClassSchedule } from "@/hooks/useClassSchedules";
import { useUIStore } from "@/stores/uiStore";
import type { ClassSchedule } from "@/types/classschedule";

interface ClassScheduleFormProps {
  editSchedule?: ClassSchedule | null;
  disciplineId: string;
  onClose: () => void;
}

export default function ClassScheduleForm({ editSchedule, disciplineId, onClose }: ClassScheduleFormProps) {
  const modalOpen = useUIStore((s) => s.modalOpen);
  const createSchedule = useCreateClassSchedule();
  const updateSchedule = useUpdateClassSchedule();

  const [dayOfWeek, setDayOfWeek] = useState(0);
  const [startTime, setStartTime] = useState("10:00");
  const [endTime, setEndTime] = useState("11:40");
  const [classType, setClassType] = useState("lecture");
  const [location, setLocation] = useState("");

  useEffect(() => {
    if (editSchedule) {
      setDayOfWeek(editSchedule.day_of_week);
      setStartTime(editSchedule.start_time.slice(0, 5));
      setEndTime(editSchedule.end_time.slice(0, 5));
      setClassType(editSchedule.class_type);
      setLocation(editSchedule.location);
    } else {
      setDayOfWeek(0);
      setStartTime("10:00");
      setEndTime("11:40");
      setClassType("lecture");
      setLocation("");
    }
  }, [editSchedule]);

  if (modalOpen !== "classschedule-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const payload = {
      discipline: disciplineId,
      day_of_week: dayOfWeek,
      start_time: startTime + ":00",
      end_time: endTime + ":00",
      class_type: classType,
      location,
    };

    if (editSchedule) {
      await updateSchedule.mutateAsync({ id: editSchedule.id, ...payload });
    } else {
      await createSchedule.mutateAsync(payload);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-md rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editSchedule ? "Edit Class Schedule" : "New Class Schedule"}
          </h3>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-6">
          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              Day of week
            </label>
            <select
              value={dayOfWeek}
              onChange={(e) => setDayOfWeek(Number(e.target.value))}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
            >
              {DAYS_OF_WEEK.map((d) => (
                <option key={d.value} value={d.value}>
                  {d.label}
                </option>
              ))}
            </select>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                Start time
              </label>
              <input
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                End time
              </label>
              <input
                type="time"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                Type
              </label>
              <select
                value={classType}
                onChange={(e) => setClassType(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {CLASS_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                Location
              </label>
              <input
                type="text"
                placeholder="Room, building..."
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl px-3 py-1.5 text-xs text-[var(--color-text-secondary)] hover:bg-white/5 hover:text-[var(--color-text-primary)]"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={createSchedule.isPending || updateSchedule.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editSchedule ? "Update" : "Create"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

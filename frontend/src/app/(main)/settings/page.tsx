"use client";

import { useState, useEffect } from "react";
import { Save } from "lucide-react";
import { useUserProfile, useUpdateUserProfile } from "@/hooks/useUserProfile";
import { emitToast } from "@/components/Toast";
import type { UserProfileUpdate } from "@/types/userprofile";

export default function SettingsPage() {
  const { data: profile, isLoading } = useUserProfile();
  const updateProfile = useUpdateUserProfile();

  const [form, setForm] = useState<UserProfileUpdate>({});
  const [hasChanges, setHasChanges] = useState(false);

  useEffect(() => {
    if (profile) {
      setForm({
        timezone: profile.timezone,
        week_starts_on: profile.week_starts_on,
        pomodoro_work_minutes: profile.pomodoro_work_minutes,
        pomodoro_short_break_minutes: profile.pomodoro_short_break_minutes,
        pomodoro_long_break_minutes: profile.pomodoro_long_break_minutes,
        pomodoros_before_long_break: profile.pomodoros_before_long_break,
        daily_work_goal_hours: profile.daily_work_goal_hours,
        daily_study_goal_hours: profile.daily_study_goal_hours,
      });
      setHasChanges(false);
    }
  }, [profile]);

  const handleChange = (field: keyof UserProfileUpdate, value: string | number) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setHasChanges(true);
  };

  const handleSave = async () => {
    try {
      await updateProfile.mutateAsync(form);
      setHasChanges(false);
      emitToast("Settings saved successfully");
    } catch {
      // Error toast handled by global interceptor
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <span className="text-sm text-[var(--color-text-muted)]">Loading...</span>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Settings</h1>
        <button
          onClick={handleSave}
          disabled={!hasChanges || updateProfile.isPending}
          className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Save className="h-3.5 w-3.5" />
          {updateProfile.isPending ? "Saving..." : "Save"}
        </button>
      </div>

      {/* Pomodoro Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          Pomodoro
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <NumberField
            label="Work (minutes)"
            value={form.pomodoro_work_minutes ?? 25}
            onChange={(v) => handleChange("pomodoro_work_minutes", v)}
            min={1}
            max={120}
          />
          <NumberField
            label="Short break (minutes)"
            value={form.pomodoro_short_break_minutes ?? 5}
            onChange={(v) => handleChange("pomodoro_short_break_minutes", v)}
            min={1}
            max={60}
          />
          <NumberField
            label="Long break (minutes)"
            value={form.pomodoro_long_break_minutes ?? 15}
            onChange={(v) => handleChange("pomodoro_long_break_minutes", v)}
            min={1}
            max={60}
          />
          <NumberField
            label="Sessions before long break"
            value={form.pomodoros_before_long_break ?? 4}
            onChange={(v) => handleChange("pomodoros_before_long_break", v)}
            min={1}
            max={10}
          />
        </div>
      </section>

      {/* Daily Goals Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          Daily Goals
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <NumberField
            label="Work hours"
            value={form.daily_work_goal_hours ?? 8}
            onChange={(v) => handleChange("daily_work_goal_hours", v)}
            min={0}
            max={24}
            step={0.5}
          />
          <NumberField
            label="Study hours"
            value={form.daily_study_goal_hours ?? 4}
            onChange={(v) => handleChange("daily_study_goal_hours", v)}
            min={0}
            max={24}
            step={0.5}
          />
        </div>
      </section>

      {/* General Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          General
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              Week starts on
            </label>
            <select
              value={form.week_starts_on ?? "monday"}
              onChange={(e) => handleChange("week_starts_on", e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
            >
              <option value="monday">Monday</option>
              <option value="sunday">Sunday</option>
            </select>
          </div>
          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              Timezone
            </label>
            <input
              type="text"
              value={form.timezone ?? "UTC"}
              onChange={(e) => handleChange("timezone", e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              placeholder="e.g. America/Sao_Paulo"
            />
          </div>
        </div>
      </section>
    </div>
  );
}

function NumberField({
  label,
  value,
  onChange,
  min,
  max,
  step = 1,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min: number;
  max: number;
  step?: number;
}) {
  return (
    <div>
      <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
        {label}
      </label>
      <input
        type="number"
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        min={min}
        max={max}
        step={step}
        className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
      />
    </div>
  );
}

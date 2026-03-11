"use client";

import { useState, useEffect } from "react";
import { Save } from "lucide-react";
import { useTranslations } from "next-intl";

import ColorSwatchPicker from "@/components/ColorSwatchPicker";
import UserAvatar from "@/components/UserAvatar";
import { emitToast } from "@/components/Toast";
import { useChangePassword, useLogout, useUpdateProfile } from "@/hooks/useAuth";
import { useUserProfile, useUpdateUserProfile } from "@/hooks/useUserProfile";
import { useAuthStore } from "@/stores/authStore";
import type { UserProfileUpdate } from "@/types/userprofile";

export default function SettingsPage() {
  const t = useTranslations("settings");
  const tco = useTranslations("common");
  const user = useAuthStore((s) => s.user);
  const updateProfile = useUpdateProfile();
  const changePassword = useChangePassword();
  const logout = useLogout();
  const { data: userProfile, isLoading: profileLoading } = useUserProfile();
  const updateUserProfile = useUpdateUserProfile();

  // Profile form state (PR #8)
  const [firstName, setFirstName] = useState(user?.first_name ?? "");
  const [lastName, setLastName] = useState(user?.last_name ?? "");
  const [email, setEmail] = useState(user?.email ?? "");
  const [avatarColor, setAvatarColor] = useState(user?.avatar_color ?? "#a3a3a3");

  // Password form state (PR #8)
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [newPasswordConfirm, setNewPasswordConfirm] = useState("");
  const [passwordError, setPasswordError] = useState("");

  // Preferences form state (PR #10)
  const [prefsForm, setPrefsForm] = useState<UserProfileUpdate>({});
  const [prefsChanged, setPrefsChanged] = useState(false);

  useEffect(() => {
    if (userProfile) {
      setPrefsForm({
        timezone: userProfile.timezone,
        week_starts_on: userProfile.week_starts_on,
        pomodoro_work_minutes: userProfile.pomodoro_work_minutes,
        pomodoro_short_break_minutes: userProfile.pomodoro_short_break_minutes,
        pomodoro_long_break_minutes: userProfile.pomodoro_long_break_minutes,
        pomodoros_before_long_break: userProfile.pomodoros_before_long_break,
        daily_work_goal_hours: userProfile.daily_work_goal_hours,
        daily_study_goal_hours: userProfile.daily_study_goal_hours,
      });
      setPrefsChanged(false);
    }
  }, [userProfile]);

  if (!user) return null;

  const previewUser = { ...user, first_name: firstName, last_name: lastName, avatar_color: avatarColor };

  const handlePrefsChange = (field: keyof UserProfileUpdate, value: string | number) => {
    setPrefsForm((prev) => ({ ...prev, [field]: value }));
    setPrefsChanged(true);
  };

  const handlePrefsSave = async () => {
    try {
      await updateUserProfile.mutateAsync(prefsForm);
      setPrefsChanged(false);
      emitToast(t("settingsSaved"));
    } catch {
      // Error toast handled by global interceptor
    }
  };

  function handleProfileSubmit(e: React.FormEvent) {
    e.preventDefault();
    updateProfile.mutate(
      { first_name: firstName, last_name: lastName, email, avatar_color: avatarColor },
      { onSuccess: () => emitToast(t("profileUpdated")) }
    );
  }

  function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault();
    setPasswordError("");
    if (newPassword !== newPasswordConfirm) {
      setPasswordError(t("passwordsDoNotMatch"));
      return;
    }
    changePassword.mutate(
      { old_password: oldPassword, new_password: newPassword, new_password_confirm: newPasswordConfirm },
      {
        onSuccess: () => {
          emitToast(t("passwordChanged"));
          logout();
        },
        onError: (err) => {
          const data = (err as { response?: { data?: Record<string, string[]> } }).response?.data;
          const message =
            data?.old_password?.[0] ??
            data?.new_password?.[0] ??
            data?.new_password_confirm?.[0] ??
            data?.non_field_errors?.[0] ??
            t("failedToChangePassword");
          setPasswordError(message);
        },
      }
    );
  }

  const inputClass =
    "w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40";
  const labelClass =
    "mb-1.5 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]";

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">{t("title")}</h1>

      {/* Profile Section */}
      <form onSubmit={handleProfileSubmit} className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-sm font-semibold text-[var(--color-text-primary)]">{t("profile")}</h2>

        <div className="mb-4 flex items-center gap-4">
          <UserAvatar user={previewUser} size="lg" />
          <div className="flex-1">
            <ColorSwatchPicker value={avatarColor} onChange={setAvatarColor} />
          </div>
        </div>

        <div className="mb-3">
          <label className={labelClass}>{t("username")}</label>
          <p className="text-sm text-[var(--color-text-secondary)]">{user.username}</p>
        </div>

        <div className="mb-3">
          <label className={labelClass}>{t("firstName")}</label>
          <input
            type="text"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
            className={inputClass}
            placeholder={t("firstNamePlaceholder")}
          />
        </div>

        <div className="mb-3">
          <label className={labelClass}>{t("lastName")}</label>
          <input
            type="text"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
            className={inputClass}
            placeholder={t("lastNamePlaceholder")}
          />
        </div>

        <div className="mb-4">
          <label className={labelClass}>{t("email")}</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={inputClass}
            placeholder={t("emailPlaceholder")}
          />
        </div>

        <button
          type="submit"
          disabled={updateProfile.isPending}
          className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {updateProfile.isPending ? t("saving") : tco("save")}
        </button>
      </form>

      {/* Pomodoro Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            {t("pomodoro")}
          </h2>
          <button
            onClick={handlePrefsSave}
            disabled={!prefsChanged || updateUserProfile.isPending}
            className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <Save className="h-3.5 w-3.5" />
            {updateUserProfile.isPending ? t("saving") : tco("save")}
          </button>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <NumberField
            label={t("workMinutes")}
            value={prefsForm.pomodoro_work_minutes ?? 25}
            onChange={(v) => handlePrefsChange("pomodoro_work_minutes", v)}
            min={1}
            max={120}
          />
          <NumberField
            label={t("shortBreakMinutes")}
            value={prefsForm.pomodoro_short_break_minutes ?? 5}
            onChange={(v) => handlePrefsChange("pomodoro_short_break_minutes", v)}
            min={1}
            max={60}
          />
          <NumberField
            label={t("longBreakMinutes")}
            value={prefsForm.pomodoro_long_break_minutes ?? 15}
            onChange={(v) => handlePrefsChange("pomodoro_long_break_minutes", v)}
            min={1}
            max={60}
          />
          <NumberField
            label={t("sessionsBeforeLongBreak")}
            value={prefsForm.pomodoros_before_long_break ?? 4}
            onChange={(v) => handlePrefsChange("pomodoros_before_long_break", v)}
            min={1}
            max={10}
          />
        </div>
      </section>

      {/* Daily Goals Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          {t("dailyGoals")}
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <NumberField
            label={t("workHours")}
            value={prefsForm.daily_work_goal_hours ?? 8}
            onChange={(v) => handlePrefsChange("daily_work_goal_hours", v)}
            min={0}
            max={24}
            step={0.5}
          />
          <NumberField
            label={t("studyHours")}
            value={prefsForm.daily_study_goal_hours ?? 4}
            onChange={(v) => handlePrefsChange("daily_study_goal_hours", v)}
            min={0}
            max={24}
            step={0.5}
          />
        </div>
      </section>

      {/* General Section */}
      <section className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          {t("general")}
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {t("weekStartsOn")}
            </label>
            <select
              value={prefsForm.week_starts_on ?? "monday"}
              onChange={(e) => handlePrefsChange("week_starts_on", e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
            >
              <option value="monday">{t("monday")}</option>
              <option value="sunday">{t("sunday")}</option>
            </select>
          </div>
          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {t("timezone")}
            </label>
            <input
              type="text"
              value={prefsForm.timezone ?? "UTC"}
              onChange={(e) => handlePrefsChange("timezone", e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              placeholder={t("timezonePlaceholder")}
            />
          </div>
        </div>
      </section>

      {/* Password Section */}
      <form onSubmit={handlePasswordSubmit} className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-sm font-semibold text-[var(--color-text-primary)]">{t("changePassword")}</h2>

        {passwordError && (
          <p className="mb-3 text-xs text-red-400">{passwordError}</p>
        )}

        <div className="mb-3">
          <label className={labelClass}>{t("currentPassword")}</label>
          <input
            type="password"
            value={oldPassword}
            onChange={(e) => setOldPassword(e.target.value)}
            className={inputClass}
            placeholder={t("currentPasswordPlaceholder")}
          />
        </div>

        <div className="mb-3">
          <label className={labelClass}>{t("newPassword")}</label>
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            className={inputClass}
            placeholder={t("newPasswordPlaceholder")}
          />
        </div>

        <div className="mb-4">
          <label className={labelClass}>{t("confirmNewPassword")}</label>
          <input
            type="password"
            value={newPasswordConfirm}
            onChange={(e) => setNewPasswordConfirm(e.target.value)}
            className={inputClass}
            placeholder={t("confirmNewPasswordPlaceholder")}
          />
        </div>

        <button
          type="submit"
          disabled={changePassword.isPending || !oldPassword || !newPassword || !newPasswordConfirm}
          className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {changePassword.isPending ? t("changing") : t("changePassword")}
        </button>
      </form>

      {/* Logout Section */}
      <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <button
          type="button"
          onClick={logout}
          className="rounded-xl px-4 py-1.5 text-xs font-medium text-red-400 transition-colors hover:bg-red-400/10"
        >
          {t("logOut")}
        </button>
      </div>
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

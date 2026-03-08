"use client";

import { useState } from "react";

import ColorSwatchPicker from "@/components/ColorSwatchPicker";
import UserAvatar from "@/components/UserAvatar";
import { emitToast } from "@/components/Toast";
import { useChangePassword, useLogout, useUpdateProfile } from "@/hooks/useAuth";
import { useAuthStore } from "@/stores/authStore";

export default function SettingsPage() {
  const user = useAuthStore((s) => s.user);
  const updateProfile = useUpdateProfile();
  const changePassword = useChangePassword();
  const logout = useLogout();

  const [firstName, setFirstName] = useState(user?.first_name ?? "");
  const [lastName, setLastName] = useState(user?.last_name ?? "");
  const [email, setEmail] = useState(user?.email ?? "");
  const [avatarColor, setAvatarColor] = useState(user?.avatar_color ?? "#a3a3a3");

  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [newPasswordConfirm, setNewPasswordConfirm] = useState("");
  const [passwordError, setPasswordError] = useState("");

  if (!user) return null;

  const previewUser = { ...user, first_name: firstName, last_name: lastName, avatar_color: avatarColor };

  function handleProfileSubmit(e: React.FormEvent) {
    e.preventDefault();
    updateProfile.mutate(
      { first_name: firstName, last_name: lastName, email, avatar_color: avatarColor },
      { onSuccess: () => emitToast("Profile updated") }
    );
  }

  function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault();
    setPasswordError("");
    if (newPassword !== newPasswordConfirm) {
      setPasswordError("New passwords do not match.");
      return;
    }
    changePassword.mutate(
      { old_password: oldPassword, new_password: newPassword, new_password_confirm: newPasswordConfirm },
      {
        onSuccess: () => {
          emitToast("Password changed");
          setOldPassword("");
          setNewPassword("");
          setNewPasswordConfirm("");
        },
        onError: (err) => {
          const message =
            (err as { response?: { data?: { old_password?: string[] } } }).response?.data?.old_password?.[0] ??
            "Failed to change password.";
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
    <div className="mx-auto max-w-lg space-y-6 p-6">
      <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Settings</h1>

      {/* Profile Section */}
      <form onSubmit={handleProfileSubmit} className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-sm font-semibold text-[var(--color-text-primary)]">Profile</h2>

        <div className="mb-4 flex items-center gap-4">
          <UserAvatar user={previewUser} size="lg" />
          <div className="flex-1">
            <ColorSwatchPicker value={avatarColor} onChange={setAvatarColor} />
          </div>
        </div>

        <div className="mb-3">
          <label className={labelClass}>Username</label>
          <p className="text-sm text-[var(--color-text-secondary)]">{user.username}</p>
        </div>

        <div className="mb-3">
          <label className={labelClass}>First Name</label>
          <input
            type="text"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
            className={inputClass}
            placeholder="First name"
          />
        </div>

        <div className="mb-3">
          <label className={labelClass}>Last Name</label>
          <input
            type="text"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
            className={inputClass}
            placeholder="Last name"
          />
        </div>

        <div className="mb-4">
          <label className={labelClass}>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={inputClass}
            placeholder="Email"
          />
        </div>

        <button
          type="submit"
          disabled={updateProfile.isPending}
          className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {updateProfile.isPending ? "Saving..." : "Save"}
        </button>
      </form>

      {/* Password Section */}
      <form onSubmit={handlePasswordSubmit} className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <h2 className="mb-4 text-sm font-semibold text-[var(--color-text-primary)]">Change Password</h2>

        {passwordError && (
          <p className="mb-3 text-xs text-red-400">{passwordError}</p>
        )}

        <div className="mb-3">
          <label className={labelClass}>Current Password</label>
          <input
            type="password"
            value={oldPassword}
            onChange={(e) => setOldPassword(e.target.value)}
            className={inputClass}
            placeholder="Current password"
          />
        </div>

        <div className="mb-3">
          <label className={labelClass}>New Password</label>
          <input
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            className={inputClass}
            placeholder="New password"
          />
        </div>

        <div className="mb-4">
          <label className={labelClass}>Confirm New Password</label>
          <input
            type="password"
            value={newPasswordConfirm}
            onChange={(e) => setNewPasswordConfirm(e.target.value)}
            className={inputClass}
            placeholder="Confirm new password"
          />
        </div>

        <button
          type="submit"
          disabled={changePassword.isPending || !oldPassword || !newPassword || !newPasswordConfirm}
          className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {changePassword.isPending ? "Changing..." : "Change Password"}
        </button>
      </form>

      {/* Logout Section */}
      <div className="rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-5">
        <button
          type="button"
          onClick={logout}
          className="rounded-xl px-4 py-1.5 text-xs font-medium text-red-400 transition-colors hover:bg-red-400/10"
        >
          Log out
        </button>
      </div>
    </div>
  );
}

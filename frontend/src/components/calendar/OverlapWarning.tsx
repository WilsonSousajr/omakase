"use client";

import { useTranslations } from "next-intl";
import { AlertTriangle } from "lucide-react";

interface OverlapItem {
  title: string;
  start_time: string;
  end_time: string;
}

interface OverlapWarningProps {
  overlaps: OverlapItem[];
  onConfirm: () => void;
  onCancel: () => void;
}

export default function OverlapWarning({
  overlaps,
  onConfirm,
  onCancel,
}: OverlapWarningProps) {
  const t = useTranslations("calendar");

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="fixed inset-0 bg-black/50" onClick={onCancel} />
      <div className="relative z-10 w-full max-w-sm rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)] p-5 shadow-xl">
        <div className="mb-3 flex items-center gap-2">
          <AlertTriangle className="h-4 w-4 text-amber-500" />
          <h3 className="text-sm font-medium text-[var(--color-text-primary)]">
            {t("overlapWarning")}
          </h3>
        </div>

        <p className="mb-3 text-xs text-[var(--color-text-muted)]">
          {t("overlapsWith")}
        </p>

        <div className="mb-4 space-y-1.5">
          {overlaps.map((item, i) => (
            <div
              key={i}
              className="flex items-center gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <span className="text-xs font-medium text-[var(--color-text-muted)] tabular-nums">
                {item.start_time.slice(0, 5)} – {item.end_time.slice(0, 5)}
              </span>
              <span className="truncate text-xs text-[var(--color-text-primary)]">
                {item.title}
              </span>
            </div>
          ))}
        </div>

        <div className="flex justify-end gap-2">
          <button
            onClick={onCancel}
            className="rounded-xl px-4 py-2 text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            {t("cancelPlacement")}
          </button>
          <button
            onClick={onConfirm}
            className="rounded-xl bg-[var(--color-button-primary)] px-4 py-2 text-sm text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)]"
          >
            {t("placeAnyway")}
          </button>
        </div>
      </div>
    </div>
  );
}

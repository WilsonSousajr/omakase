"use client";

import { useTranslations } from "next-intl";

interface Props {
  win: string;
  onChangeWin: (value: string) => void;
  onNext: () => void;
}

export default function ReviewWin({ win, onChangeWin, onNext }: Props) {
  const t = useTranslations("review");
  const tc = useTranslations("common");

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          {t("win.title")}
        </h2>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          {t("win.subtitle")}
        </p>
      </div>

      <textarea
        value={win}
        onChange={(e) => onChangeWin(e.target.value)}
        placeholder={t("win.placeholder")}
        rows={3}
        className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
      />

      <div className="flex items-center justify-between">
        <button
          onClick={onNext}
          className="text-xs text-[var(--color-text-faint)] hover:text-[var(--color-text-secondary)]"
        >
          {t("win.skip")}
        </button>
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          {tc("continue")}
        </button>
      </div>
    </div>
  );
}

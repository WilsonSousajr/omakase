"use client";

import { useTranslations } from "next-intl";

interface Props {
  rating: number | null;
  onRate: (rating: number) => void;
  onNext: () => void;
}

export default function ReviewScore({ rating, onRate, onNext }: Props) {
  const t = useTranslations("review");
  const tc = useTranslations("common");

  return (
    <div className="space-y-8 text-center">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          {t("score.title")}
        </h2>
      </div>

      <div className="flex justify-center gap-3">
        {[1, 2, 3, 4, 5].map((value) => {
          const isSelected = rating === value;
          return (
            <button
              key={value}
              onClick={() => onRate(value)}
              className={`flex flex-col items-center gap-1.5 rounded-2xl border px-4 py-3 transition-all ${
                isSelected
                  ? "border-[var(--color-text-primary)] bg-[var(--color-overlay-medium)] ring-1 ring-[var(--color-ring-overlay)]"
                  : "border-[var(--color-border)] hover:bg-[var(--color-hover-overlay)]"
              }`}
            >
              <span className="text-xl font-semibold text-[var(--color-text-primary)]">
                {value}
              </span>
              <span className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t(`score.labels.${value}`)}
              </span>
            </button>
          );
        })}
      </div>

      <div className="flex justify-end">
        <button
          onClick={onNext}
          disabled={rating === null}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          {tc("continue")}
        </button>
      </div>
    </div>
  );
}

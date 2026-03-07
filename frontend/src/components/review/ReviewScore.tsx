"use client";

interface Props {
  rating: number | null;
  onRate: (rating: number) => void;
  onNext: () => void;
}

const LABELS = ["Rough", "Below avg", "Decent", "Good", "Crushing it"];

export default function ReviewScore({ rating, onRate, onNext }: Props) {
  return (
    <div className="space-y-8 text-center">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          How productive did you feel today?
        </h2>
      </div>

      <div className="flex justify-center gap-3">
        {LABELS.map((label, i) => {
          const value = i + 1;
          const isSelected = rating === value;
          return (
            <button
              key={value}
              onClick={() => onRate(value)}
              className={`flex flex-col items-center gap-1.5 rounded-2xl border px-4 py-3 transition-all ${
                isSelected
                  ? "border-[var(--color-text-primary)] bg-white/10 ring-1 ring-white/20"
                  : "border-[var(--color-border)] hover:bg-white/5"
              }`}
            >
              <span className="text-xl font-semibold text-[var(--color-text-primary)]">
                {value}
              </span>
              <span className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {label}
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
          Continue
        </button>
      </div>
    </div>
  );
}

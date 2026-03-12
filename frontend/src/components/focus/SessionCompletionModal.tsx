"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";
import { useUpdateTimeBlock } from "@/hooks/useTimeBlocks";
import type { TimeBlock } from "@/types/timeblock";

interface SessionCompletionModalProps {
  block: TimeBlock;
  onClose: () => void;
}

export default function SessionCompletionModal({ block, onClose }: SessionCompletionModalProps) {
  const t = useTranslations("focus");
  const tCommon = useTranslations("common");
  const updateTimeBlock = useUpdateTimeBlock();
  const [rating, setRating] = useState<number | null>(null);
  const [notes, setNotes] = useState(block.notes || "");

  const handleSave = () => {
    updateTimeBlock.mutate({
      id: block.id,
      session_rating: rating,
      notes,
    });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="fixed inset-0 bg-black/50" onClick={onClose} />
      <div className="relative z-10 w-full max-w-md rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg)] p-6 shadow-xl">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute right-4 top-4 rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
        >
          <X className="h-4 w-4" />
        </button>

        {/* Title */}
        <h3 className="mb-1 text-sm font-medium text-[var(--color-text-primary)]">
          {t("sessionComplete")}
        </h3>
        <p className="mb-4 text-xs text-[var(--color-text-muted)]">
          {t("howDidItGo")}
        </p>

        {/* Rating circles */}
        <div className="mb-4">
          <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-secondary)]">
            {t("sessionRating")}
          </label>
          <div className="flex gap-2">
            {[1, 2, 3, 4, 5].map((value) => (
              <button
                key={value}
                onClick={() => setRating(value)}
                className={cn(
                  "flex h-10 w-10 items-center justify-center rounded-full border text-sm font-medium transition-all",
                  rating === value
                    ? "border-[var(--color-text-primary)] bg-[var(--color-surface-active)] text-[var(--color-text-primary)]"
                    : "border-[var(--color-border)] text-[var(--color-text-muted)] hover:border-[var(--color-border-hover)] hover:text-[var(--color-text-secondary)]"
                )}
              >
                {value}
              </button>
            ))}
          </div>
        </div>

        {/* Notes */}
        <div className="mb-5">
          <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-secondary)]">
            {t("sessionNotes")}
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder={t("sessionNotesPlaceholder")}
            className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-faint)] focus:border-[var(--color-border-hover)] focus:outline-none"
            rows={3}
          />
        </div>

        {/* Buttons */}
        <div className="flex justify-end gap-2">
          <button
            onClick={onClose}
            className="rounded-xl px-4 py-2 text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            {tCommon("skip")}
          </button>
          <button
            onClick={handleSave}
            className="rounded-xl bg-[var(--color-button-primary)] px-4 py-2 text-sm text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)]"
          >
            {tCommon("save")}
          </button>
        </div>
      </div>
    </div>
  );
}

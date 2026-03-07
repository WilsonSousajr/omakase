"use client";

import { useState, useEffect } from "react";
import {
  useReviewSummary,
  useCreateDailyReview,
  useUpdateDailyReview,
} from "@/hooks/useDailyReviews";
import ReviewSummary from "@/components/review/ReviewSummary";
import ReviewRollover from "@/components/review/ReviewRollover";
import ReviewScore from "@/components/review/ReviewScore";
import ReviewWin from "@/components/review/ReviewWin";
import ReviewPreview from "@/components/review/ReviewPreview";
import ReviewShutdown from "@/components/review/ReviewShutdown";
import ReviewHistory from "@/components/review/ReviewHistory";
import { useToday } from "@/hooks/useToday";
import { cn } from "@/lib/utils";

const STEPS = ["Summary", "Rollover", "Score", "Win", "Preview", "Shutdown"];

export default function ReviewPage() {
  const today = useToday();
  const { data: summary, isLoading } = useReviewSummary(today);
  const createReview = useCreateDailyReview();
  const updateReview = useUpdateDailyReview();

  const [tab, setTab] = useState<"today" | "history">("today");
  const [step, setStep] = useState(0);
  const [reviewId, setReviewId] = useState<string | null>(
    summary?.daily_review?.id ?? null
  );
  const [rating, setRating] = useState<number | null>(null);
  const [win, setWin] = useState("");

  useEffect(() => {
    if (summary?.daily_review?.id && !reviewId) {
      setReviewId(summary.daily_review.id);
    }
  }, [summary?.daily_review?.id, reviewId]);

  const ensureReview = async (): Promise<string> => {
    if (reviewId) return reviewId;
    const created = await createReview.mutateAsync({ date: today });
    setReviewId(created.id);
    return created.id;
  };

  const handleNext = () => setStep((s) => Math.min(s + 1, STEPS.length - 1));

  const handleSaveRating = async () => {
    const id = await ensureReview();
    await updateReview.mutateAsync({ id, productivity_rating: rating });
    handleNext();
  };

  const handleSaveWin = async () => {
    const id = await ensureReview();
    if (win.trim()) {
      await updateReview.mutateAsync({ id, win_of_the_day: win.trim() });
    }
    handleNext();
  };

  const handleShutdown = async () => {
    const id = await ensureReview();
    await updateReview.mutateAsync({ id, is_shutdown: true });
  };

  if (isLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-[var(--color-text-faint)] border-t-[var(--color-text-primary)]" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col">
      {/* Tab bar */}
      <div className="flex border-b border-[var(--color-border)]">
        {(["today", "history"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "px-4 py-2 text-xs font-medium capitalize transition-colors",
              tab === t
                ? "border-b-2 border-[var(--color-text-primary)] text-[var(--color-text-primary)]"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]"
            )}
          >
            {t === "today" ? "Today" : "History"}
          </button>
        ))}
      </div>

      {tab === "today" ? (
        <>
          {/* Step indicator */}
          <div className="flex items-center justify-center gap-1.5 border-b border-[var(--color-border)] px-6 py-3">
            {STEPS.map((label, i) => (
              <div key={label} className="flex items-center gap-1.5">
                <div
                  className={`h-1.5 w-1.5 rounded-full ${
                    i <= step
                      ? "bg-[var(--color-text-primary)]"
                      : "bg-[var(--color-text-faint)]"
                  }`}
                />
                {i < STEPS.length - 1 && (
                  <div
                    className={`h-px w-6 ${
                      i < step
                        ? "bg-[var(--color-text-primary)]"
                        : "bg-[var(--color-text-faint)]"
                    }`}
                  />
                )}
              </div>
            ))}
          </div>

          {/* Step content */}
          <div className="flex flex-1 items-center justify-center overflow-auto p-8">
            <div className="w-full max-w-2xl">
              {step === 0 && summary && (
                <ReviewSummary summary={summary} onNext={handleNext} />
              )}
              {step === 1 && summary && (
                <ReviewRollover summary={summary} onNext={handleNext} />
              )}
              {step === 2 && (
                <ReviewScore
                  rating={rating}
                  onRate={setRating}
                  onNext={handleSaveRating}
                />
              )}
              {step === 3 && (
                <ReviewWin win={win} onChangeWin={setWin} onNext={handleSaveWin} />
              )}
              {step === 4 && <ReviewPreview onNext={handleNext} />}
              {step === 5 && <ReviewShutdown onShutdown={handleShutdown} />}
            </div>
          </div>
        </>
      ) : (
        <div className="flex-1 overflow-auto p-8">
          <div className="mx-auto w-full max-w-2xl">
            <ReviewHistory />
          </div>
        </div>
      )}
    </div>
  );
}

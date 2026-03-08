"use client";

import { useState, useEffect } from "react";
import { useDailyReviewsList } from "@/hooks/useDailyReviews";
import ReviewHistoryCard from "./ReviewHistoryCard";
import type { DailyReview } from "@/types/dailyreview";

export default function ReviewHistory() {
  const [page, setPage] = useState(1);
  const [allReviews, setAllReviews] = useState<DailyReview[]>([]);
  const { data, isLoading } = useDailyReviewsList(page);

  useEffect(() => {
    if (!data) return;
    if (page === 1) {
      setAllReviews(data.results);
    } else {
      setAllReviews((prev) => {
        const existingIds = new Set(prev.map((r) => r.id));
        const newReviews = data.results.filter((r) => !existingIds.has(r.id));
        return [...prev, ...newReviews];
      });
    }
  }, [data, page]);

  if (isLoading && allReviews.length === 0) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-[var(--color-text-faint)] border-t-[var(--color-text-primary)]" />
      </div>
    );
  }

  if (allReviews.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <p className="text-sm text-[var(--color-text-muted)]">
          No past reviews yet
        </p>
        <p className="mt-1 text-xs text-[var(--color-text-faint)]">
          Complete your first daily review to see it here
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {allReviews.map((review) => (
        <ReviewHistoryCard key={review.id} review={review} />
      ))}

      {data?.next && (
        <div className="flex justify-center pt-2">
          <button
            onClick={() => setPage((p) => p + 1)}
            disabled={isLoading}
            className="rounded-xl border border-[var(--color-border)] px-6 py-2 text-xs font-medium text-[var(--color-text-muted)] transition-colors hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-secondary)] disabled:opacity-50"
          >
            {isLoading ? "Loading..." : "Load more"}
          </button>
        </div>
      )}
    </div>
  );
}

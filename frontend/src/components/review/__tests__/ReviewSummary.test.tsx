import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import ReviewSummary from "../ReviewSummary";
import type { ReviewSummary as ReviewSummaryType } from "@/types/dailyreview";

const baseSummary: ReviewSummaryType = {
  date: "2026-03-06",
  hours_focused: 2.5,
  blocks_completed: 3,
  blocks_total: 5,
  incomplete_tasks: [
    {
      id: "1",
      title: "Pending task",
      priority: "medium",
      area: "work",
      estimated_minutes: 30,
    },
  ],
  incomplete_study_blocks: [],
  completed_items: [
    {
      id: "2",
      title: "Done task",
      type: "task",
      estimated_minutes: 30,
      actual_minutes: 45,
    },
  ],
  daily_review: null,
};

describe("ReviewSummary", () => {
  it("renders stats", () => {
    render(<ReviewSummary summary={baseSummary} onNext={vi.fn()} />);
    expect(screen.getByText("2.5h")).toBeInTheDocument();
    expect(screen.getByText("3/5")).toBeInTheDocument();
    expect(screen.getByText("60%")).toBeInTheDocument();
  });

  it("renders completed and incomplete items", () => {
    render(<ReviewSummary summary={baseSummary} onNext={vi.fn()} />);
    expect(screen.getByText("Done task")).toBeInTheDocument();
    expect(screen.getByText("Pending task")).toBeInTheDocument();
  });

  it("calls onNext when Continue clicked", async () => {
    const onNext = vi.fn();
    render(<ReviewSummary summary={baseSummary} onNext={onNext} />);
    await userEvent.click(screen.getByText("Continue"));
    expect(onNext).toHaveBeenCalledOnce();
  });
});

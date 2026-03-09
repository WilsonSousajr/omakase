import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { setupServer } from "msw/node";
import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import ReviewHistoryCard from "../ReviewHistoryCard";
import { renderWithProviders } from "@/test/utils";
import { handlers } from "@/test/handlers";
import type { DailyReview } from "@/types/dailyreview";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

const baseReview: DailyReview = {
  id: "rev-1",
  date: "2026-03-06",
  productivity_rating: 4,
  win_of_the_day: "Shipped the review feature",
  is_shutdown: true,
  shutdown_at: "2026-03-06T23:00:00Z",
  created_at: "2026-03-06T22:00:00Z",
  updated_at: "2026-03-06T23:00:00Z",
};

describe("ReviewHistoryCard", () => {
  it("renders date and year", () => {
    renderWithProviders(<ReviewHistoryCard review={baseReview} />);
    expect(screen.getByText("Friday, March 6")).toBeInTheDocument();
    expect(screen.getByText("2026")).toBeInTheDocument();
  });

  it("renders rating dots when rating is present", () => {
    const { container } = renderWithProviders(
      <ReviewHistoryCard review={baseReview} />
    );
    const dots = container.querySelectorAll(".h-1\\.5.w-1\\.5.rounded-full");
    expect(dots).toHaveLength(5);
  });

  it("renders win excerpt with quotes", () => {
    renderWithProviders(<ReviewHistoryCard review={baseReview} />);
    expect(
      screen.getByText(/Shipped the review feature/)
    ).toBeInTheDocument();
  });

  it("hides win excerpt when empty", () => {
    renderWithProviders(
      <ReviewHistoryCard review={{ ...baseReview, win_of_the_day: "" }} />
    );
    const winElements = screen.queryAllByText(/\u201c/);
    expect(winElements).toHaveLength(0);
  });

  it("shows moon icon when shutdown", () => {
    const { container } = renderWithProviders(
      <ReviewHistoryCard review={baseReview} />
    );
    expect(container.querySelector(".lucide-moon")).toBeInTheDocument();
  });

  it("hides moon icon when not shutdown", () => {
    const { container } = renderWithProviders(
      <ReviewHistoryCard review={{ ...baseReview, is_shutdown: false }} />
    );
    expect(container.querySelector(".lucide-moon")).not.toBeInTheDocument();
  });

  it("expands and shows summary stats on click", async () => {
    renderWithProviders(<ReviewHistoryCard review={baseReview} />);
    await userEvent.click(screen.getByRole("button"));
    await waitFor(() => {
      expect(screen.getByText("Hours Focused")).toBeInTheDocument();
    });
    expect(screen.getByText("Blocks Completed")).toBeInTheDocument();
    expect(screen.getByText("Completion")).toBeInTheDocument();
  });

  it("collapses expanded view on second click", async () => {
    renderWithProviders(<ReviewHistoryCard review={baseReview} />);
    const button = screen.getByRole("button");
    await userEvent.click(button);
    await userEvent.click(button);
    expect(screen.queryByText("Win of the day")).not.toBeInTheDocument();
  });

  it("hides rating dots when rating is null", () => {
    const { container } = renderWithProviders(
      <ReviewHistoryCard
        review={{ ...baseReview, productivity_rating: null }}
      />
    );
    const dots = container.querySelectorAll(".h-1\\.5.w-1\\.5.rounded-full");
    expect(dots).toHaveLength(0);
  });
});

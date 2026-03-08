import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers } from "@/test/handlers";
import { createTestQueryClient } from "@/test/utils";
import { useReviewSummary, useCreateDailyReview, useDailyReviewsList } from "@/hooks/useDailyReviews";
import type { ReactNode } from "react";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

describe("useReviewSummary", () => {
  it("fetches review summary for a date", async () => {
    const { result } = renderHook(() => useReviewSummary("2026-03-06"), {
      wrapper,
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.date).toBe("2026-03-06");
    expect(result.current.data?.incomplete_tasks).toEqual([]);
  });
});

describe("useDailyReviewsList", () => {
  it("fetches paginated list of all reviews", async () => {
    const { result } = renderHook(() => useDailyReviewsList(1), {
      wrapper,
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.results).toHaveLength(2);
    expect(result.current.data?.results[0].date).toBe("2026-03-06");
    expect(result.current.data?.results[1].date).toBe("2026-03-05");
  });

  it("returns paginated response with count and next", async () => {
    const { result } = renderHook(() => useDailyReviewsList(1), {
      wrapper,
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.count).toBe(2);
    expect(result.current.data?.next).toBeNull();
  });
});

describe("useCreateDailyReview", () => {
  it("creates a daily review", async () => {
    const { result } = renderHook(() => useCreateDailyReview(), {
      wrapper,
    });
    result.current.mutate({ date: "2026-03-06" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.date).toBe("2026-03-06");
  });
});

import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useDailyStats } from "../useStats";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockDailyStats } from "@/test/handlers";
import type { ReactNode } from "react";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

const API_URL = "http://localhost:8000/api/v1";

describe("useDailyStats", () => {
  it("fetches daily stats", async () => {
    const { result } = renderHook(() => useDailyStats(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.hours_focused_today).toBe(2.5);
    expect(result.current.data?.blocks_completed_today).toBe(3);
    expect(result.current.data?.blocks_total_today).toBe(5);
    expect(result.current.data?.current_streak).toBe(7);
    expect(result.current.data?.weekly_work_hours).toBe(12.0);
    expect(result.current.data?.weekly_study_hours).toBe(4.5);
  });

  it("handles custom stats data", async () => {
    server.use(
      http.get(`${API_URL}/stats/daily/`, () =>
        HttpResponse.json(createMockDailyStats({
          hours_focused_today: 5.0,
          current_streak: 30,
        }))
      )
    );
    const { result } = renderHook(() => useDailyStats(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.hours_focused_today).toBe(5.0);
    expect(result.current.data?.current_streak).toBe(30);
  });

  it("handles error state", async () => {
    server.use(
      http.get(`${API_URL}/stats/daily/`, () =>
        new HttpResponse(null, { status: 500 })
      )
    );
    const { result } = renderHook(() => useDailyStats(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

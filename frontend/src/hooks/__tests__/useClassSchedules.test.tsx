import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useClassSchedules } from "../useClassSchedules";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockClassSchedule } from "@/test/handlers";
import type { ReactNode } from "react";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

const API_URL = "http://localhost:8000/api/v1";

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

describe("useClassSchedules", () => {
  it("fetches class schedules list", async () => {
    const { result } = renderHook(() => useClassSchedules(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
  });

  it("handles empty schedules", async () => {
    server.use(
      http.get(`${API_URL}/study/classschedules/`, () =>
        HttpResponse.json({ count: 0, results: [] })
      )
    );
    const { result } = renderHook(() => useClassSchedules(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(0);
  });

  it("returns schedules with expected shape", async () => {
    const mockSchedule = createMockClassSchedule({ day_of_week: 2, class_type: "lab" });
    server.use(
      http.get(`${API_URL}/study/classschedules/`, () =>
        HttpResponse.json({ count: 1, results: [mockSchedule] })
      )
    );
    const { result } = renderHook(() => useClassSchedules(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.[0].day_of_week).toBe(2);
    expect(result.current.data?.[0].class_type).toBe("lab");
  });

  it("handles error state", async () => {
    server.use(
      http.get(`${API_URL}/study/classschedules/`, () =>
        new HttpResponse(null, { status: 500 })
      )
    );
    const { result } = renderHook(() => useClassSchedules(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

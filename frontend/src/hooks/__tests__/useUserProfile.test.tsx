import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useUserProfile, useUpdateUserProfile } from "../useUserProfile";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockUserProfile } from "@/test/handlers";
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

describe("useUserProfile", () => {
  it("fetches user profile with defaults", async () => {
    const { result } = renderHook(() => useUserProfile(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data!.timezone).toBe("UTC");
    expect(result.current.data!.week_starts_on).toBe("monday");
    expect(result.current.data!.pomodoro_work_minutes).toBe(25);
    expect(result.current.data!.pomodoro_short_break_minutes).toBe(5);
    expect(result.current.data!.pomodoro_long_break_minutes).toBe(15);
    expect(result.current.data!.pomodoros_before_long_break).toBe(4);
    expect(result.current.data!.daily_work_goal_hours).toBe(8.0);
    expect(result.current.data!.daily_study_goal_hours).toBe(4.0);
  });
});

describe("useUpdateUserProfile", () => {
  it("patches user profile", async () => {
    server.use(
      http.patch(`${API_URL}/auth/profile/`, async ({ request }) => {
        const body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(createMockUserProfile(body));
      })
    );
    const { result } = renderHook(() => useUpdateUserProfile(), { wrapper });
    const updated = await result.current.mutateAsync({
      pomodoro_work_minutes: 50,
      timezone: "America/Sao_Paulo",
    });
    expect(updated.pomodoro_work_minutes).toBe(50);
    expect(updated.timezone).toBe("America/Sao_Paulo");
  });
});

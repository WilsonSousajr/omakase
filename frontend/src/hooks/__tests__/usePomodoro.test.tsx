import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook } from "@testing-library/react";
import { setupServer } from "msw/node";
import { useCreatePomodoroSession, useCompletePomodoroSession } from "../usePomodoro";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers } from "@/test/handlers";
import type { ReactNode } from "react";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

describe("useCreatePomodoroSession", () => {
  it("posts new session", async () => {
    const { result } = renderHook(() => useCreatePomodoroSession(), { wrapper });
    const session = await result.current.mutateAsync({
      session_type: "focus",
      duration_minutes: 25,
    });
    expect(session.session_type).toBe("focus");
    expect(session.duration_minutes).toBe(25);
  });
});

describe("useCompletePomodoroSession", () => {
  it("patches session as completed", async () => {
    const { result } = renderHook(() => useCompletePomodoroSession(), { wrapper });
    const session = await result.current.mutateAsync({
      id: "session-id",
      ended_at: "2025-01-15T10:30:00Z",
    });
    expect(session.completed).toBe(true);
  });
});

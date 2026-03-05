import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useSemesters } from "../useSemesters";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockSemester } from "@/test/handlers";
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

describe("useSemesters", () => {
  it("fetches semesters list", async () => {
    const { result } = renderHook(() => useSemesters(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data?.[0].name).toBe("2026.1");
    expect(result.current.data?.[1].name).toBe("2025.2");
  });

  it("handles empty semesters", async () => {
    server.use(
      http.get(`${API_URL}/study/semesters/`, () =>
        HttpResponse.json({ count: 0, results: [] })
      )
    );
    const { result } = renderHook(() => useSemesters(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(0);
  });

  it("handles error state", async () => {
    server.use(
      http.get(`${API_URL}/study/semesters/`, () =>
        new HttpResponse(null, { status: 500 })
      )
    );
    const { result } = renderHook(() => useSemesters(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

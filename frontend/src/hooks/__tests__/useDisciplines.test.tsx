import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useDisciplines } from "../useDisciplines";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockDiscipline } from "@/test/handlers";
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

describe("useDisciplines", () => {
  it("fetches disciplines list", async () => {
    const { result } = renderHook(() => useDisciplines(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data?.[0].name).toBe("Calculo 2");
    expect(result.current.data?.[1].name).toBe("Algebra Linear");
  });

  it("fetches disciplines filtered by semester", async () => {
    const semesterId = "test-sem-id";
    server.use(
      http.get(`${API_URL}/study/disciplines/`, ({ request }) => {
        const url = new URL(request.url);
        const semester = url.searchParams.get("semester");
        if (semester === semesterId) {
          return HttpResponse.json({
            count: 1,
            results: [createMockDiscipline({ name: "Filtered", semester: semesterId })],
          });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(
      () => useDisciplines({ semester: semesterId }),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
    expect(result.current.data?.[0].name).toBe("Filtered");
  });

  it("handles error state", async () => {
    server.use(
      http.get(`${API_URL}/study/disciplines/`, () =>
        new HttpResponse(null, { status: 500 })
      )
    );
    const { result } = renderHook(() => useDisciplines(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

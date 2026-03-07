import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useClassOccurrences } from "../useClassOccurrences";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockClassOccurrence } from "@/test/handlers";
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

describe("useClassOccurrences", () => {
  it("fetches occurrences for a date range", async () => {
    const { result } = renderHook(
      () => useClassOccurrences("2026-03-01", "2026-03-07"),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data?.[0].discipline_name).toBe("Calculo 2");
  });

  it("is disabled when dates are missing", () => {
    const { result } = renderHook(() => useClassOccurrences(), { wrapper });
    expect(result.current.fetchStatus).toBe("idle");
  });

  it("handles empty occurrences", async () => {
    server.use(
      http.get(`${API_URL}/study/class-occurrences/`, () =>
        HttpResponse.json([])
      )
    );
    const { result } = renderHook(
      () => useClassOccurrences("2026-03-01", "2026-03-07"),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(0);
  });

  it("returns occurrences with expected shape", async () => {
    const mockOcc = createMockClassOccurrence({
      discipline_name: "Algebra Linear",
      location: "Lab B",
      class_type: "lab",
    });
    server.use(
      http.get(`${API_URL}/study/class-occurrences/`, () =>
        HttpResponse.json([mockOcc])
      )
    );
    const { result } = renderHook(
      () => useClassOccurrences("2026-03-01", "2026-03-07"),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.[0].discipline_name).toBe("Algebra Linear");
    expect(result.current.data?.[0].location).toBe("Lab B");
    expect(result.current.data?.[0].class_type).toBe("lab");
  });
});

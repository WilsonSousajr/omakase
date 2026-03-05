import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useStudyBlocks } from "../useStudyBlocks";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockStudyBlock } from "@/test/handlers";
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

describe("useStudyBlocks", () => {
  it("fetches study blocks list", async () => {
    const { result } = renderHook(() => useStudyBlocks(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data?.[0].title).toBe("Chapter 5");
    expect(result.current.data?.[1].title).toBe("Problem Set 3");
  });

  it("fetches study blocks filtered by discipline", async () => {
    const discId = "test-disc-id";
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, ({ request }) => {
        const url = new URL(request.url);
        const discipline = url.searchParams.get("discipline");
        if (discipline === discId) {
          return HttpResponse.json({
            count: 1,
            results: [createMockStudyBlock({ title: "Filtered Block", discipline: discId })],
          });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(
      () => useStudyBlocks({ discipline: discId }),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
    expect(result.current.data?.[0].title).toBe("Filtered Block");
  });

  it("fetches study blocks filtered by scheduled_date", async () => {
    const date = "2026-03-04";
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, ({ request }) => {
        const url = new URL(request.url);
        const scheduledDate = url.searchParams.get("scheduled_date");
        if (scheduledDate === date) {
          return HttpResponse.json({
            count: 1,
            results: [createMockStudyBlock({ title: "Today Block", scheduled_date: date })],
          });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(
      () => useStudyBlocks({ scheduled_date: date }),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
    expect(result.current.data?.[0].scheduled_date).toBe(date);
  });

  it("handles error state", async () => {
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, () =>
        new HttpResponse(null, { status: 500 })
      )
    );
    const { result } = renderHook(() => useStudyBlocks(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

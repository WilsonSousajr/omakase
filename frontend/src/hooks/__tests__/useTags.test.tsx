import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useTags, useCreateTag } from "../useTags";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockTag } from "@/test/handlers";
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

describe("useTags", () => {
  it("fetches tag list", async () => {
    const { result } = renderHook(() => useTags(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
  });

  it("passes area filter", async () => {
    const workTags = [createMockTag({ area: "work" })];
    server.use(
      http.get(`${API_URL}/tags/`, ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get("area") === "work") {
          return HttpResponse.json({ count: 1, results: workTags });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(() => useTags("work"), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
  });
});

describe("useCreateTag", () => {
  it("posts new tag", async () => {
    const { result } = renderHook(() => useCreateTag(), { wrapper });
    const tag = await result.current.mutateAsync({
      name: "New Tag",
      color: "#ff0000",
      area: "work",
    });
    expect(tag.name).toBe("New Tag");
  });
});

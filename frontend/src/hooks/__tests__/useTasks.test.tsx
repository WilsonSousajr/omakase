import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useTasks, useTodayTasks, useCreateTask, useUpdateTask, useDeleteTask, useReorderTasks } from "../useTasks";
import { useTimeBlocks } from "../useTimeBlocks";
import { createTestQueryClient } from "@/test/utils";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockTask, createMockTimeBlock } from "@/test/handlers";
import type { ReactNode } from "react";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function wrapper({ children }: { children: ReactNode }) {
  const queryClient = createTestQueryClient();
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}

function createWrapperWithClient(queryClient: QueryClient) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
  };
}

const API_URL = "http://localhost:8000/api/v1";

describe("useTasks", () => {
  it("fetches task list", async () => {
    const { result } = renderHook(() => useTasks(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(3);
  });

  it("passes filter params", async () => {
    const tasks = [createMockTask({ priority: "high" })];
    server.use(
      http.get(`${API_URL}/tasks/`, ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get("priority") === "high") {
          return HttpResponse.json({ count: 1, next: null, previous: null, results: tasks });
        }
        return HttpResponse.json({ count: 0, next: null, previous: null, results: [] });
      })
    );
    const { result } = renderHook(() => useTasks({ priority: "high" }), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
  });
});

describe("useTodayTasks", () => {
  it("fetches today's tasks with date param", async () => {
    const { result } = renderHook(() => useTodayTasks("2026-03-07"), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toBeDefined();
  });
});

describe("useCreateTask", () => {
  it("posts new task", async () => {
    const { result } = renderHook(() => useCreateTask(), { wrapper });
    const task = await result.current.mutateAsync({ title: "New task" });
    expect(task.title).toBe("New task");
  });
});

describe("useUpdateTask", () => {
  it("patches task", async () => {
    const { result } = renderHook(() => useUpdateTask(), { wrapper });
    const task = await result.current.mutateAsync({ id: "abc", title: "Updated" });
    expect(task.title).toBe("Updated");
  });
});

describe("useDeleteTask", () => {
  it("deletes task", async () => {
    const { result } = renderHook(() => useDeleteTask(), { wrapper });
    await expect(result.current.mutateAsync("abc")).resolves.toBeUndefined();
  });

  it("invalidates timeblocks cache after deleting a task", async () => {
    let timeblockFetchCount = 0;
    server.use(
      http.get(`${API_URL}/timeblocks/`, () => {
        timeblockFetchCount++;
        return HttpResponse.json({
          count: 1,
          results: [createMockTimeBlock()],
        });
      })
    );

    const queryClient = createTestQueryClient();
    const sharedWrapper = createWrapperWithClient(queryClient);

    // Prime the timeblocks cache
    const { result: tbResult } = renderHook(
      () => useTimeBlocks("2026-03-08", "2026-03-08"),
      { wrapper: sharedWrapper }
    );
    await waitFor(() => expect(tbResult.current.isSuccess).toBe(true));
    const fetchCountAfterPrime = timeblockFetchCount;

    // Delete a task — should invalidate timeblocks cache
    const { result: deleteResult } = renderHook(() => useDeleteTask(), {
      wrapper: sharedWrapper,
    });
    await deleteResult.current.mutateAsync("abc");

    // The timeblocks endpoint should be re-fetched after task deletion
    await waitFor(() => expect(timeblockFetchCount).toBeGreaterThan(fetchCountAfterPrime));
  });
});

describe("useReorderTasks", () => {
  it("patches bulk reorder", async () => {
    const { result } = renderHook(() => useReorderTasks(), { wrapper });
    await expect(
      result.current.mutateAsync([
        { id: "a", kanban_order: 0, kanban_status: "todo" as const },
      ])
    ).resolves.toBeUndefined();
  });
});

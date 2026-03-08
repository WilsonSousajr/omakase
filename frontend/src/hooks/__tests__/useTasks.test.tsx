import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useTasks, useTodayTasks, useCreateTask, useUpdateTask, useDeleteTask, useReorderTasks } from "../useTasks";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockTask } from "@/test/handlers";
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

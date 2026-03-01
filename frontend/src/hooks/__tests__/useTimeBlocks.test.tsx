import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { useTimeBlocks, useCreateTimeBlock, useUpdateTimeBlock, useDeleteTimeBlock } from "../useTimeBlocks";
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

describe("useTimeBlocks", () => {
  it("fetches time blocks with date range", async () => {
    const { result } = renderHook(
      () => useTimeBlocks("2025-01-01", "2025-01-31"),
      { wrapper }
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
  });

  it("is disabled without dateFrom", () => {
    const { result } = renderHook(() => useTimeBlocks(), { wrapper });
    expect(result.current.fetchStatus).toBe("idle");
  });
});

describe("useCreateTimeBlock", () => {
  it("posts new time block", async () => {
    const { result } = renderHook(() => useCreateTimeBlock(), { wrapper });
    const block = await result.current.mutateAsync({
      task: "task-id",
      date: "2025-01-15",
      start_time: "09:00:00",
      end_time: "10:00:00",
    });
    expect(block.date).toBe("2025-01-15");
  });
});

describe("useUpdateTimeBlock", () => {
  it("patches time block", async () => {
    const { result } = renderHook(() => useUpdateTimeBlock(), { wrapper });
    const block = await result.current.mutateAsync({
      id: "block-id",
      end_time: "11:00:00",
    });
    expect(block.end_time).toBe("11:00:00");
  });
});

describe("useDeleteTimeBlock", () => {
  it("deletes time block", async () => {
    const { result } = renderHook(() => useDeleteTimeBlock(), { wrapper });
    await expect(result.current.mutateAsync("block-id")).resolves.toBeUndefined();
  });
});

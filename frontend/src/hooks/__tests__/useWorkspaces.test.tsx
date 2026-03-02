import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useWorkspaces, useCreateWorkspace, useUpdateWorkspace, useDeleteWorkspace } from "../useWorkspaces";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockWorkspace } from "@/test/handlers";
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

describe("useWorkspaces", () => {
  it("fetches workspace list", async () => {
    const { result } = renderHook(() => useWorkspaces(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data![0].name).toBe("Work");
  });
});

describe("useCreateWorkspace", () => {
  it("posts new workspace", async () => {
    const { result } = renderHook(() => useCreateWorkspace(), { wrapper });
    const workspace = await result.current.mutateAsync({
      name: "New Workspace",
      color: "#6366f1",
    });
    expect(workspace.name).toBe("New Workspace");
  });
});

describe("useUpdateWorkspace", () => {
  it("patches existing workspace", async () => {
    const workspaceId = crypto.randomUUID();
    server.use(
      http.patch(`${API_URL}/workspaces/:id/`, async ({ request, params }) => {
        const body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(createMockWorkspace({ id: params.id, ...body }));
      })
    );
    const { result } = renderHook(() => useUpdateWorkspace(), { wrapper });
    const workspace = await result.current.mutateAsync({
      id: workspaceId,
      name: "Updated Workspace",
    });
    expect(workspace.name).toBe("Updated Workspace");
  });
});

describe("useDeleteWorkspace", () => {
  it("deletes workspace", async () => {
    const workspaceId = crypto.randomUUID();
    const { result } = renderHook(() => useDeleteWorkspace(), { wrapper });
    await expect(result.current.mutateAsync(workspaceId)).resolves.toBeUndefined();
  });
});

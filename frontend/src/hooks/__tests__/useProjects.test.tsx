import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { useProjects, useCreateProject, useUpdateProject, useDeleteProject } from "../useProjects";
import { createTestQueryClient } from "@/test/utils";
import { QueryClientProvider } from "@tanstack/react-query";
import { handlers, createMockProject } from "@/test/handlers";
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

describe("useProjects", () => {
  it("fetches project list", async () => {
    const { result } = renderHook(() => useProjects(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(2);
    expect(result.current.data![0].name).toBe("Project Alpha");
  });

  it("passes workspace filter", async () => {
    const workspaceId = crypto.randomUUID();
    const filtered = [createMockProject({ workspace: workspaceId, name: "Filtered" })];
    server.use(
      http.get(`${API_URL}/projects/`, ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get("workspace") === workspaceId) {
          return HttpResponse.json({ count: 1, results: filtered });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(() => useProjects({ workspace: workspaceId }), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
    expect(result.current.data![0].name).toBe("Filtered");
  });

  it("passes status filter", async () => {
    const completed = [createMockProject({ status: "completed", name: "Done" })];
    server.use(
      http.get(`${API_URL}/projects/`, ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get("status") === "completed") {
          return HttpResponse.json({ count: 1, results: completed });
        }
        return HttpResponse.json({ count: 0, results: [] });
      })
    );
    const { result } = renderHook(() => useProjects({ status: "completed" }), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
    expect(result.current.data![0].status).toBe("completed");
  });
});

describe("useCreateProject", () => {
  it("posts new project", async () => {
    const { result } = renderHook(() => useCreateProject(), { wrapper });
    const project = await result.current.mutateAsync({
      workspace: crypto.randomUUID(),
      name: "New Project",
    });
    expect(project.name).toBe("New Project");
  });
});

describe("useUpdateProject", () => {
  it("patches existing project", async () => {
    const { result } = renderHook(() => useUpdateProject(), { wrapper });
    const project = await result.current.mutateAsync({
      id: crypto.randomUUID(),
      name: "Updated Project",
    });
    expect(project.name).toBe("Updated Project");
  });
});

describe("useDeleteProject", () => {
  it("deletes project", async () => {
    const projectId = crypto.randomUUID();
    const { result } = renderHook(() => useDeleteProject(), { wrapper });
    await expect(result.current.mutateAsync(projectId)).resolves.toBeUndefined();
  });
});

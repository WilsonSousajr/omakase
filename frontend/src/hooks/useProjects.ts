import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Project, ProjectCreate, ProjectUpdate } from "@/types/project";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

interface ProjectFilters {
  workspace?: string;
  status?: string;
}

export function useProjects(filters?: ProjectFilters) {
  return useQuery({
    queryKey: ["projects", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters?.workspace) params.workspace = filters.workspace;
      if (filters?.status) params.status = filters.status;
      const { data } = await api.get<PaginatedResponse<Project>>("/projects/", { params });
      return data.results;
    },
  });
}

export function useCreateProject() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (project: ProjectCreate) => {
      const { data } = await api.post<Project>("/projects/", project);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["projects"] });
      queryClient.invalidateQueries({ queryKey: ["workspaces"] });
    },
  });
}

export function useUpdateProject() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: ProjectUpdate & { id: string }) => {
      const { data } = await api.patch<Project>(`/projects/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["projects"] });
    },
  });
}

export function useDeleteProject() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/projects/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["projects"] });
      queryClient.invalidateQueries({ queryKey: ["workspaces"] });
    },
  });
}

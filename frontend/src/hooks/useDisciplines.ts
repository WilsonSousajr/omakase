import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Discipline, DisciplineCreate, DisciplineUpdate } from "@/types/discipline";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

interface DisciplineFilters {
  semester?: string;
  status?: string;
}

export function useDisciplines(filters?: DisciplineFilters) {
  return useQuery({
    queryKey: ["disciplines", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters?.semester) params.semester = filters.semester;
      if (filters?.status) params.status = filters.status;
      const { data } = await api.get<PaginatedResponse<Discipline>>("/study/disciplines/", { params });
      return data.results;
    },
  });
}

export function useCreateDiscipline() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (discipline: DisciplineCreate) => {
      const { data } = await api.post<Discipline>("/study/disciplines/", discipline);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["disciplines"] });
      queryClient.invalidateQueries({ queryKey: ["semesters"] });
    },
  });
}

export function useUpdateDiscipline() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: DisciplineUpdate & { id: string }) => {
      const { data } = await api.patch<Discipline>(`/study/disciplines/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["disciplines"] });
    },
  });
}

export function useDeleteDiscipline() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/study/disciplines/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["disciplines"] });
      queryClient.invalidateQueries({ queryKey: ["semesters"] });
    },
  });
}

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Semester, SemesterCreate, SemesterUpdate } from "@/types/semester";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

export function useSemesters() {
  return useQuery({
    queryKey: ["semesters"],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<Semester>>("/study/semesters/");
      return data.results;
    },
  });
}

export function useCreateSemester() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (semester: SemesterCreate) => {
      const { data } = await api.post<Semester>("/study/semesters/", semester);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["semesters"] });
    },
  });
}

export function useUpdateSemester() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: SemesterUpdate & { id: string }) => {
      const { data } = await api.patch<Semester>(`/study/semesters/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["semesters"] });
    },
  });
}

export function useDeleteSemester() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/study/semesters/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["semesters"] });
    },
  });
}

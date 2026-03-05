import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { ClassSchedule, ClassScheduleCreate, ClassScheduleUpdate } from "@/types/classschedule";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

interface ClassScheduleFilters {
  discipline?: string;
  class_type?: string;
  is_active?: boolean;
}

export function useClassSchedules(filters?: ClassScheduleFilters) {
  return useQuery({
    queryKey: ["classschedules", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters?.discipline) params.discipline = filters.discipline;
      if (filters?.class_type) params.class_type = filters.class_type;
      if (filters?.is_active !== undefined) params.is_active = String(filters.is_active);
      const { data } = await api.get<PaginatedResponse<ClassSchedule>>("/study/classschedules/", { params });
      return data.results;
    },
  });
}

export function useCreateClassSchedule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (schedule: ClassScheduleCreate) => {
      const { data } = await api.post<ClassSchedule>("/study/classschedules/", schedule);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["classschedules"] });
    },
  });
}

export function useUpdateClassSchedule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: ClassScheduleUpdate & { id: string }) => {
      const { data } = await api.patch<ClassSchedule>(`/study/classschedules/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["classschedules"] });
    },
  });
}

export function useDeleteClassSchedule() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/study/classschedules/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["classschedules"] });
    },
  });
}

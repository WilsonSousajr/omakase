import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { StudyBlock, StudyBlockCreate, StudyBlockUpdate } from "@/types/studyblock";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

interface StudyBlockFilters {
  discipline?: string;
  block_type?: string;
  status?: string;
  scheduled_date?: string;
}

export function useStudyBlocks(filters?: StudyBlockFilters) {
  return useQuery({
    queryKey: ["studyblocks", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters?.discipline) params.discipline = filters.discipline;
      if (filters?.block_type) params.block_type = filters.block_type;
      if (filters?.status) params.status = filters.status;
      if (filters?.scheduled_date) params.scheduled_date = filters.scheduled_date;
      const { data } = await api.get<PaginatedResponse<StudyBlock>>("/study/studyblocks/", { params });
      return data.results;
    },
  });
}

export function useCreateStudyBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (block: StudyBlockCreate) => {
      const { data } = await api.post<StudyBlock>("/study/studyblocks/", block);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studyblocks"] });
      queryClient.invalidateQueries({ queryKey: ["disciplines"] });
    },
  });
}

export function useUpdateStudyBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: StudyBlockUpdate & { id: string }) => {
      const { data } = await api.patch<StudyBlock>(`/study/studyblocks/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studyblocks"] });
    },
  });
}

export function useDeleteStudyBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/study/studyblocks/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["studyblocks"] });
      queryClient.invalidateQueries({ queryKey: ["disciplines"] });
    },
  });
}

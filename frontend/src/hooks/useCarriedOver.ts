import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Task } from "@/types/task";
import type { StudyBlock } from "@/types/studyblock";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

export function useCarriedOverTasks(date: string) {
  return useQuery({
    queryKey: ["tasks", "carried-over", date],
    queryFn: async () => {
      const { data } = await api.get<Task[] | PaginatedResponse<Task>>("/tasks/carried-over/", {
        params: { date },
      });
      return Array.isArray(data) ? data : data.results;
    },
    enabled: !!date,
  });
}

export function useCarriedOverStudyBlocks(date: string) {
  return useQuery({
    queryKey: ["studyblocks", "carried-over", date],
    queryFn: async () => {
      const { data } = await api.get<StudyBlock[] | PaginatedResponse<StudyBlock>>(
        "/study/studyblocks/carried-over/",
        { params: { date } },
      );
      return Array.isArray(data) ? data : data.results;
    },
    enabled: !!date,
  });
}

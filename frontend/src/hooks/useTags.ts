import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Tag, TagCreate } from "@/types/tag";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

export function useTags(area?: string) {
  return useQuery({
    queryKey: ["tags", area],
    queryFn: async () => {
      const params = area ? { area } : {};
      const { data } = await api.get<PaginatedResponse<Tag>>("/tags/", { params });
      return data.results;
    },
  });
}

export function useCreateTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (tag: TagCreate) => {
      const { data } = await api.post<Tag>("/tags/", tag);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tags"] });
    },
  });
}

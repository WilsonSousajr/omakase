import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { TimeBlock, TimeBlockCreate } from "@/types/timeblock";

interface PaginatedResponse<T> {
  count: number;
  results: T[];
}

export function useTimeBlocks(dateFrom?: string, dateTo?: string) {
  return useQuery({
    queryKey: ["timeblocks", dateFrom, dateTo],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (dateFrom) params.date_from = dateFrom;
      if (dateTo) params.date_to = dateTo;
      const { data } = await api.get<PaginatedResponse<TimeBlock>>("/timeblocks/", {
        params,
      });
      return data.results;
    },
    enabled: !!dateFrom,
  });
}

export function useCreateTimeBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (block: TimeBlockCreate) => {
      const { data } = await api.post<TimeBlock>("/timeblocks/", block);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useUpdateTimeBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<TimeBlockCreate> & { id: string }) => {
      const { data } = await api.patch<TimeBlock>(`/timeblocks/${id}/`, updates);
      return data;
    },
    onMutate: async ({ id, ...updates }) => {
      // Cancel in-flight queries so they don't overwrite our optimistic update
      await queryClient.cancelQueries({ queryKey: ["timeblocks"] });
      // Snapshot previous cache for rollback
      const previousData = queryClient.getQueriesData<TimeBlock[]>({ queryKey: ["timeblocks"] });
      queryClient.setQueriesData<TimeBlock[]>(
        { queryKey: ["timeblocks"] },
        (old) => old?.map((b) => (b.id === id ? { ...b, ...updates } : b)),
      );
      return { previousData };
    },
    onError: (_err, _vars, context) => {
      // Restore previous cache on failure
      context?.previousData?.forEach(([key, data]) => {
        queryClient.setQueryData(key, data);
      });
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useDeleteTimeBlock() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/timeblocks/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

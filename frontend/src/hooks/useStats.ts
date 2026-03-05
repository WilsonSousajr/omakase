import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import type { DailyStats } from "@/types/stats";

const STATS_REFETCH_MS = 60_000;

export function useDailyStats() {
  return useQuery({
    queryKey: ["stats", "daily"],
    queryFn: async () => {
      const { data } = await api.get<DailyStats>("/stats/daily/");
      return data;
    },
    refetchInterval: STATS_REFETCH_MS,
  });
}

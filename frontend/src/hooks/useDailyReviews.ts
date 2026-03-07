import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { DailyReview, ReviewSummary } from "@/types/dailyreview";

interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export function useDailyReviewsList(page: number = 1) {
  return useQuery({
    queryKey: ["daily-reviews", "list", page],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<DailyReview>>(
        "/stats/reviews/",
        { params: { page } }
      );
      return data;
    },
  });
}

export function useReviewSummary(date: string) {
  return useQuery({
    queryKey: ["review-summary", date],
    queryFn: async () => {
      const { data } = await api.get<ReviewSummary>("/stats/review/", {
        params: { date },
      });
      return data;
    },
    enabled: !!date,
  });
}

export function useDailyReview(date: string) {
  return useQuery({
    queryKey: ["daily-reviews", date],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<DailyReview>>(
        "/stats/reviews/",
        { params: { date } }
      );
      return data.results[0] ?? null;
    },
    enabled: !!date,
  });
}

export function useCreateDailyReview() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { date: string }) => {
      const { data } = await api.post<DailyReview>("/stats/reviews/", payload);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["daily-reviews"] });
      queryClient.invalidateQueries({ queryKey: ["review-summary"] });
    },
  });
}

export function useUpdateDailyReview() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      ...updates
    }: { id: string } & Partial<
      Pick<DailyReview, "productivity_rating" | "win_of_the_day" | "is_shutdown">
    >) => {
      const { data } = await api.patch<DailyReview>(
        `/stats/reviews/${id}/`,
        updates
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["daily-reviews"] });
      queryClient.invalidateQueries({ queryKey: ["review-summary"] });
    },
  });
}

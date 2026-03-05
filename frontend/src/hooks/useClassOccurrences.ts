import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import type { ClassOccurrence } from "@/types/classschedule";

export function useClassOccurrences(dateFrom?: string, dateTo?: string) {
  return useQuery({
    queryKey: ["class-occurrences", dateFrom, dateTo],
    queryFn: async () => {
      const { data } = await api.get<ClassOccurrence[]>("/study/class-occurrences/", {
        params: { date_from: dateFrom, date_to: dateTo },
      });
      return data;
    },
    enabled: !!dateFrom && !!dateTo,
  });
}

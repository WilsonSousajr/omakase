import { useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { PomodoroSession, PomodoroSessionCreate } from "@/types/pomodoro";

export function useCreatePomodoroSession() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (session: PomodoroSessionCreate) => {
      const { data } = await api.post<PomodoroSession>("/pomodoro/sessions/", session);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["pomodoro"] });
    },
  });
}

export function useCompletePomodoroSession() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ended_at }: { id: string; ended_at: string }) => {
      const { data } = await api.patch<PomodoroSession>(`/pomodoro/sessions/${id}/`, {
        completed: true,
        ended_at,
      });
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["pomodoro"] });
    },
  });
}

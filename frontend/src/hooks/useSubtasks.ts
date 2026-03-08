import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Subtask, SubtaskCreate, SubtaskUpdate } from "@/types/subtask";

export function useSubtasks(taskId: string | null) {
  return useQuery({
    queryKey: ["subtasks", taskId],
    queryFn: async () => {
      const { data } = await api.get<Subtask[]>(
        `/tasks/${taskId}/subtasks/`
      );
      return data;
    },
    enabled: !!taskId,
  });
}

export function useCreateSubtask(taskId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (subtask: SubtaskCreate) => {
      const { data } = await api.post<Subtask>(
        `/tasks/${taskId}/subtasks/`,
        subtask
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["subtasks", taskId] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useUpdateSubtask(taskId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      ...updates
    }: SubtaskUpdate & { id: string }) => {
      const { data } = await api.patch<Subtask>(
        `/tasks/${taskId}/subtasks/${id}/`,
        updates
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["subtasks", taskId] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useDeleteSubtask(taskId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/tasks/${taskId}/subtasks/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["subtasks", taskId] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

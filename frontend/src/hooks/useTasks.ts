import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Task, TaskCreate, TaskUpdate, TaskReorderItem } from "@/types/task";

interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

interface TaskFilters {
  priority?: string;
  area?: string;
  kanban_status?: string;
  scheduled_date?: string;
  is_completed?: boolean;
  search?: string;
}

export function useTasks(filters?: TaskFilters) {
  return useQuery({
    queryKey: ["tasks", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters?.priority) params.priority = filters.priority;
      if (filters?.area) params.area = filters.area;
      if (filters?.kanban_status) params.kanban_status = filters.kanban_status;
      if (filters?.scheduled_date) params.scheduled_date = filters.scheduled_date;
      if (filters?.is_completed !== undefined) params.is_completed = String(filters.is_completed);
      if (filters?.search) params.search = filters.search;
      const { data } = await api.get<PaginatedResponse<Task>>("/tasks/", { params });
      return data.results;
    },
  });
}

export function useTodayTasks() {
  return useQuery({
    queryKey: ["tasks", "today"],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<Task> | Task[]>("/tasks/today/");
      return Array.isArray(data) ? data : data.results;
    },
  });
}

export function useTask(id: string | null) {
  return useQuery({
    queryKey: ["tasks", id],
    queryFn: async () => {
      const { data } = await api.get<Task>(`/tasks/${id}/`);
      return data;
    },
    enabled: !!id,
  });
}

export function useCreateTask() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (task: TaskCreate) => {
      const { data } = await api.post<Task>("/tasks/", task);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useUpdateTask() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...updates }: TaskUpdate & { id: string }) => {
      const { data } = await api.patch<Task>(`/tasks/${id}/`, updates);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useDeleteTask() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/tasks/${id}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useReorderTasks() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (items: TaskReorderItem[]) => {
      await api.patch("/tasks/reorder-bulk/", items);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
    },
  });
}

export function useToggleTaskComplete() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, is_completed }: { id: string; is_completed: boolean }) => {
      const response = await api.patch(`/tasks/${id}/`, { is_completed });
      return response.data;
    },
    onMutate: async ({ id, is_completed }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ["tasks"] });

      // Snapshot all task query keys for proper rollback
      const previousQueriesData = queryClient.getQueriesData<Task[]>({ queryKey: ["tasks"] });

      // Optimistically update all task queries
      queryClient.setQueriesData<Task[]>(
        { queryKey: ["tasks"] },
        (old) => old?.map(t =>
          t.id === id
            ? {
                ...t,
                is_completed,
                kanban_status: is_completed ? 'done' : 'todo',
                completed_at: is_completed ? new Date().toISOString() : null
              }
            : t
        )
      );

      return { previousQueriesData };
    },
    onError: (_err, _variables, context) => {
      // Rollback all task query keys
      context?.previousQueriesData?.forEach(([queryKey, data]) => {
        queryClient.setQueryData(queryKey, data);
      });
    },
    onSettled: () => {
      // Refetch to sync with server
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
    },
  });
}

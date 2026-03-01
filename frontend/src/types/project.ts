export interface Project {
  id: string;
  workspace: string;
  name: string;
  description: string;
  color: string;
  status: "active" | "paused" | "completed" | "archived";
  due_date: string | null;
  task_count: number;
  created_at: string;
  updated_at: string;
}

export interface ProjectCreate {
  workspace: string;
  name: string;
  color?: string;
  description?: string;
  status?: string;
  due_date?: string | null;
}

export interface ProjectUpdate extends Partial<ProjectCreate> {}

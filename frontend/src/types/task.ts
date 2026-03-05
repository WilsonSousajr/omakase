import type { Tag } from "./tag";
import type { TimeBlock } from "./timeblock";

export interface Task {
  id: string;
  title: string;
  description: string;
  notes: string;
  priority: "low" | "medium" | "high" | "urgent";
  area: "work" | "personal" | "study";
  kanban_status: "todo" | "in_progress" | "done";
  tags: Tag[];
  project: string | null;
  discipline: string | null;
  scheduled_date: string | null;
  due_date: string | null;
  estimated_minutes: number | null;
  kanban_order: number;
  is_completed: boolean;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
  time_blocks?: TimeBlock[];
}

export interface TaskCreate {
  title: string;
  description?: string;
  priority?: "low" | "medium" | "high" | "urgent";
  area?: "work" | "personal" | "study";
  kanban_status?: "todo" | "in_progress" | "done";
  tag_ids?: string[];
  project?: string | null;
  discipline?: string | null;
  scheduled_date?: string | null;
  due_date?: string | null;
  estimated_minutes?: number | null;
}

export interface TaskUpdate extends Partial<TaskCreate> {
  notes?: string;
  kanban_order?: number;
  is_completed?: boolean;
}

export interface TaskReorderItem {
  id: string;
  kanban_order: number;
  kanban_status: "todo" | "in_progress" | "done";
}

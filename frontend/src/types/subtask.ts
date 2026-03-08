export interface Subtask {
  id: string;
  title: string;
  is_completed: boolean;
  order: number;
  created_at: string;
}

export interface SubtaskCreate {
  title: string;
  order?: number;
}

export interface SubtaskUpdate {
  title?: string;
  is_completed?: boolean;
  order?: number;
}

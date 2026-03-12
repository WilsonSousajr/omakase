export interface StudyBlock {
  id: string;
  discipline: string;
  title: string;
  block_type: "theory" | "exercises" | "review" | "assignment" | "exam_prep" | "lab" | "reading";
  priority: "low" | "medium" | "high" | "urgent";
  status: "planned" | "in_progress" | "completed" | "skipped";
  notes: string;
  estimated_minutes: number | null;
  actual_minutes?: number;
  scheduled_date: string | null;
  due_date: string | null;
  is_completed: boolean;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface StudyBlockCreate {
  discipline: string;
  title: string;
  block_type?: string;
  priority?: string;
  status?: string;
  notes?: string;
  estimated_minutes?: number | null;
  scheduled_date?: string | null;
  due_date?: string | null;
}

export type StudyBlockUpdate = Partial<StudyBlockCreate> & {
  is_completed?: boolean;
};

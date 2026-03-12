export interface TimeBlock {
  id: string;
  task: string | null;
  study_block: string | null;
  date: string;
  start_time: string;
  end_time: string;
  notes: string;
  session_rating: number | null;
  created_at: string;
  updated_at: string;
}

export interface TimeBlockCreate {
  task?: string | null;
  study_block?: string | null;
  date: string;
  start_time: string;
  end_time: string;
  notes?: string;
  session_rating?: number | null;
}

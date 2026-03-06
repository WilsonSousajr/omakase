export interface DailyReview {
  id: string;
  date: string;
  productivity_rating: number | null;
  win_of_the_day: string;
  is_shutdown: boolean;
  shutdown_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ReviewSummary {
  date: string;
  hours_focused: number;
  blocks_completed: number;
  blocks_total: number;
  incomplete_tasks: ReviewIncompleteTask[];
  incomplete_study_blocks: ReviewIncompleteStudyBlock[];
  completed_items: ReviewCompletedItem[];
  daily_review: DailyReview | null;
}

export interface ReviewIncompleteTask {
  id: string;
  title: string;
  priority: string;
  area: string;
  estimated_minutes: number | null;
}

export interface ReviewIncompleteStudyBlock {
  id: string;
  title: string;
  block_type: string;
  priority: string;
  estimated_minutes: number | null;
}

export interface ReviewCompletedItem {
  id: string;
  title: string;
  type: "task" | "studyblock";
  estimated_minutes: number | null;
  actual_minutes: number;
}

export interface TimeBlock {
  id: string;
  task: string;
  date: string;
  start_time: string;
  end_time: string;
  created_at: string;
  updated_at: string;
}

export interface TimeBlockCreate {
  task: string;
  date: string;
  start_time: string;
  end_time: string;
}

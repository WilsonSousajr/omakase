export interface ClassSchedule {
  id: string;
  discipline: string;
  day_of_week: 0 | 1 | 2 | 3 | 4 | 5 | 6;
  start_time: string;
  end_time: string;
  class_type: "lecture" | "lab" | "tutorial" | "seminar";
  location: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ClassScheduleCreate {
  discipline: string;
  day_of_week: number;
  start_time: string;
  end_time: string;
  class_type?: string;
  location?: string;
  is_active?: boolean;
}

export type ClassScheduleUpdate = Partial<ClassScheduleCreate>;

export interface ClassOccurrence {
  id: string;
  class_schedule_id: string;
  discipline_name: string;
  discipline_color: string;
  class_type: string;
  location: string;
  date: string;
  start_time: string;
  end_time: string;
}

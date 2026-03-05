export interface Semester {
  id: string;
  name: string;
  institution: string;
  start_date: string;
  end_date: string;
  status: "active" | "completed" | "archived";
  discipline_count: number;
  created_at: string;
  updated_at: string;
}

export interface SemesterCreate {
  name: string;
  institution?: string;
  start_date: string;
  end_date: string;
  status?: string;
}

export type SemesterUpdate = Partial<SemesterCreate>;

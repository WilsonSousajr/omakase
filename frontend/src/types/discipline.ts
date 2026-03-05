export interface Discipline {
  id: string;
  semester: string;
  name: string;
  code: string;
  professor: string;
  color: string;
  credits: number | null;
  target_grade: number | null;
  status: "active" | "completed" | "dropped";
  study_block_count: number;
  created_at: string;
  updated_at: string;
}

export interface DisciplineCreate {
  semester: string;
  name: string;
  code?: string;
  professor?: string;
  color?: string;
  credits?: number | null;
  target_grade?: number | null;
  status?: string;
}

export type DisciplineUpdate = Partial<DisciplineCreate>;

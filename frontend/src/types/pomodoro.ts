export interface PomodoroSession {
  id: string;
  task: string | null;
  session_type: "focus" | "short_break" | "long_break";
  duration_minutes: number;
  started_at: string;
  ended_at: string | null;
  completed: boolean;
}

export interface PomodoroSessionCreate {
  task?: string | null;
  session_type: "focus" | "short_break" | "long_break";
  duration_minutes: number;
}

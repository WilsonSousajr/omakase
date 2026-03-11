export interface UserProfile {
  timezone: string;
  week_starts_on: "monday" | "sunday";
  pomodoro_work_minutes: number;
  pomodoro_short_break_minutes: number;
  pomodoro_long_break_minutes: number;
  pomodoros_before_long_break: number;
  daily_work_goal_hours: number;
  daily_study_goal_hours: number;
  created_at: string;
  updated_at: string;
}

export type UserProfileUpdate = Partial<
  Omit<UserProfile, "created_at" | "updated_at">
>;

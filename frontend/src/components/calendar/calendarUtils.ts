import { CALENDAR_START_HOUR } from "@/lib/constants";

export const SLOT_HEIGHT_DAY = 48;
export const SLOT_HEIGHT_WEEK = 40;

export const HOURS = Array.from({ length: 17 }, (_, i) => i + CALENDAR_START_HOUR); // 06:00 - 22:00

export function timeToMinutes(time: string): number {
  const [h, m] = time.split(":").map(Number);
  return h * 60 + m;
}

export function minutesToTime(minutes: number): string {
  const clamped = Math.max(0, Math.min(minutes, 22 * 60));
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:00`;
}

export function timeToOffset(
  time: string,
  slotHeight: number,
  startHour: number = CALENDAR_START_HOUR,
): number {
  const [h, m] = time.split(":").map(Number);
  return Math.max(0, ((h - startHour) * 60 + m) / 30 * (slotHeight / 2));
}

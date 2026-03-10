import { describe, it, expect } from "vitest";
import {
  timeToMinutes,
  minutesToTime,
  timeToOffset,
  HOURS,
  SLOT_HEIGHT_DAY,
  SLOT_HEIGHT_WEEK,
} from "../calendarUtils";

describe("calendarUtils", () => {
  describe("timeToMinutes", () => {
    it("converts HH:MM format to minutes", () => {
      expect(timeToMinutes("09:00")).toBe(540);
      expect(timeToMinutes("14:30")).toBe(870);
    });

    it("converts HH:MM:SS format to minutes", () => {
      expect(timeToMinutes("09:00:00")).toBe(540);
      expect(timeToMinutes("14:30:00")).toBe(870);
    });

    it("handles midnight", () => {
      expect(timeToMinutes("00:00")).toBe(0);
    });

    it("handles end of day", () => {
      expect(timeToMinutes("23:59")).toBe(1439);
    });
  });

  describe("minutesToTime", () => {
    it("converts minutes to HH:MM:SS format", () => {
      expect(minutesToTime(540)).toBe("09:00:00");
      expect(minutesToTime(870)).toBe("14:30:00");
    });

    it("clamps to 22:00 max", () => {
      expect(minutesToTime(1400)).toBe("22:00:00");
    });

    it("clamps negative to 00:00", () => {
      expect(minutesToTime(-10)).toBe("00:00:00");
    });

    it("handles midnight", () => {
      expect(minutesToTime(0)).toBe("00:00:00");
    });
  });

  describe("timeToOffset", () => {
    it("returns 0 for the start hour", () => {
      expect(timeToOffset("06:00", SLOT_HEIGHT_DAY)).toBe(0);
    });

    it("calculates correct offset for 1 hour past start", () => {
      // 1 hour = 60 min, divided by 30 = 2 slots, * (48/2) = 48px
      expect(timeToOffset("07:00", SLOT_HEIGHT_DAY)).toBe(48);
    });

    it("calculates correct offset for half hour", () => {
      // 30 min past start = 1 slot * 24 = 24px
      expect(timeToOffset("06:30", SLOT_HEIGHT_DAY)).toBe(24);
    });

    it("works with week view slot height", () => {
      // 1 hour = 60 min / 30 = 2 slots * (40/2) = 40px
      expect(timeToOffset("07:00", SLOT_HEIGHT_WEEK)).toBe(40);
    });

    it("accepts custom start hour", () => {
      // With startHour=8, "09:00" is 1 hour in = 2 slots * 24 = 48px
      expect(timeToOffset("09:00", SLOT_HEIGHT_DAY, 8)).toBe(48);
    });

    it("returns 0 for times before start hour", () => {
      expect(timeToOffset("05:00", SLOT_HEIGHT_DAY)).toBe(0);
    });

    it("handles HH:MM:SS format", () => {
      expect(timeToOffset("07:00:00", SLOT_HEIGHT_DAY)).toBe(48);
    });
  });

  describe("constants", () => {
    it("HOURS covers 06:00 to 22:00", () => {
      expect(HOURS[0]).toBe(6);
      expect(HOURS[HOURS.length - 1]).toBe(22);
      expect(HOURS).toHaveLength(17);
    });

    it("slot heights are defined", () => {
      expect(SLOT_HEIGHT_DAY).toBe(48);
      expect(SLOT_HEIGHT_WEEK).toBe(40);
    });
  });
});

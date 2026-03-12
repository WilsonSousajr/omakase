import { describe, it, expect } from "vitest";
import { findOverlaps } from "../timeblock-utils";

function makeBlock(overrides: Record<string, unknown> = {}) {
  return {
    id: crypto.randomUUID(),
    task: "task-1",
    study_block: null,
    date: "2026-03-11",
    start_time: "09:00:00",
    end_time: "10:00:00",
    notes: "",
    session_rating: null,
    created_at: "",
    updated_at: "",
    ...overrides,
  };
}

function makeClassOccurrence(overrides: Record<string, unknown> = {}) {
  return {
    discipline_name: "Calculus",
    date: "2026-03-11",
    start_time: "10:00:00",
    end_time: "11:40:00",
    ...overrides,
  };
}

describe("findOverlaps", () => {
  it("returns empty array when no overlap", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "11:00:00",
      end_time: "12:00:00",
    };
    const existing = [
      makeBlock({ start_time: "09:00:00", end_time: "10:00:00" }),
    ];
    expect(findOverlaps(proposed, existing)).toEqual([]);
  });

  it("detects partial overlap", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "09:30:00",
      end_time: "10:30:00",
    };
    const existing = [
      makeBlock({ start_time: "09:00:00", end_time: "10:00:00" }),
    ];
    const result = findOverlaps(proposed, existing);
    expect(result).toHaveLength(1);
    expect(result[0].start_time).toBe("09:00:00");
  });

  it("detects complete containment", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "08:00:00",
      end_time: "11:00:00",
    };
    const existing = [
      makeBlock({ start_time: "09:00:00", end_time: "10:00:00" }),
    ];
    const result = findOverlaps(proposed, existing);
    expect(result).toHaveLength(1);
  });

  it("adjacent blocks (end === start) are NOT overlapping", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "10:00:00",
      end_time: "11:00:00",
    };
    const existing = [
      makeBlock({ start_time: "09:00:00", end_time: "10:00:00" }),
    ];
    expect(findOverlaps(proposed, existing)).toEqual([]);
  });

  it("different dates have no overlap", () => {
    const proposed = {
      date: "2026-03-12",
      start_time: "09:00:00",
      end_time: "10:00:00",
    };
    const existing = [
      makeBlock({
        date: "2026-03-11",
        start_time: "09:00:00",
        end_time: "10:00:00",
      }),
    ];
    expect(findOverlaps(proposed, existing)).toEqual([]);
  });

  it("excludes self when repositioning (excludeBlockId)", () => {
    const blockId = "existing-block-id";
    const proposed = {
      date: "2026-03-11",
      start_time: "09:00:00",
      end_time: "10:00:00",
    };
    const existing = [
      makeBlock({
        id: blockId,
        start_time: "09:00:00",
        end_time: "10:00:00",
      }),
    ];
    expect(findOverlaps(proposed, existing, undefined, blockId)).toEqual([]);
  });

  it("detects class occurrence overlap", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "10:30:00",
      end_time: "11:30:00",
    };
    const classOccurrences = [
      makeClassOccurrence({ start_time: "10:00:00", end_time: "11:40:00" }),
    ];
    const result = findOverlaps(proposed, [], classOccurrences);
    expect(result).toHaveLength(1);
    expect(result[0].title).toBe("Calculus");
  });

  it("returns multiple overlaps from both blocks and classes", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "09:30:00",
      end_time: "11:00:00",
    };
    const existing = [
      makeBlock({ start_time: "09:00:00", end_time: "10:00:00" }),
    ];
    const classOccurrences = [
      makeClassOccurrence({ start_time: "10:00:00", end_time: "11:40:00" }),
    ];
    const result = findOverlaps(proposed, existing, classOccurrences);
    expect(result).toHaveLength(2);
  });

  it("labels task blocks as Task", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "09:00:00",
      end_time: "10:00:00",
    };
    const existing = [
      makeBlock({
        task: "task-1",
        study_block: null,
        start_time: "09:00:00",
        end_time: "10:00:00",
      }),
    ];
    const result = findOverlaps(proposed, existing);
    expect(result[0].title).toBe("Task");
  });

  it("labels study block blocks as Study Block", () => {
    const proposed = {
      date: "2026-03-11",
      start_time: "09:00:00",
      end_time: "10:00:00",
    };
    const existing = [
      makeBlock({
        task: null,
        study_block: "sb-1",
        start_time: "09:00:00",
        end_time: "10:00:00",
      }),
    ];
    const result = findOverlaps(proposed, existing);
    expect(result[0].title).toBe("Study Block");
  });
});

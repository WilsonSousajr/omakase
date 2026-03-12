import type { TimeBlock } from "@/types/timeblock";

interface TimeRange {
  title: string;
  start_time: string;
  end_time: string;
}

interface ProposedBlock {
  date: string;
  start_time: string;
  end_time: string;
}

interface ClassOccurrenceLike {
  discipline_name: string;
  date: string;
  start_time: string;
  end_time: string;
}

function timeToMinutes(time: string): number {
  const parts = time.split(":");
  return parseInt(parts[0]) * 60 + parseInt(parts[1]);
}

function timesOverlap(
  startA: string,
  endA: string,
  startB: string,
  endB: string,
): boolean {
  const a0 = timeToMinutes(startA);
  const a1 = timeToMinutes(endA);
  const b0 = timeToMinutes(startB);
  const b1 = timeToMinutes(endB);
  return a0 < b1 && a1 > b0;
}

export function findOverlaps(
  proposed: ProposedBlock,
  existingBlocks: TimeBlock[],
  classOccurrences?: ClassOccurrenceLike[],
  excludeBlockId?: string,
): TimeRange[] {
  const overlaps: TimeRange[] = [];

  for (const block of existingBlocks) {
    if (block.date !== proposed.date) continue;
    if (excludeBlockId && block.id === excludeBlockId) continue;

    if (
      timesOverlap(
        proposed.start_time,
        proposed.end_time,
        block.start_time,
        block.end_time,
      )
    ) {
      overlaps.push({
        title: block.task ? "Task" : "Study Block",
        start_time: block.start_time,
        end_time: block.end_time,
      });
    }
  }

  if (classOccurrences) {
    for (const occ of classOccurrences) {
      if (occ.date !== proposed.date) continue;

      if (
        timesOverlap(
          proposed.start_time,
          proposed.end_time,
          occ.start_time,
          occ.end_time,
        )
      ) {
        overlaps.push({
          title: occ.discipline_name,
          start_time: occ.start_time,
          end_time: occ.end_time,
        });
      }
    }
  }

  return overlaps;
}

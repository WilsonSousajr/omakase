"use client";

import { useEffect } from "react";
import { format } from "date-fns";
import KanbanBoard from "@/components/kanban/KanbanBoard";
import TodayStudyBlocks from "@/components/kanban/TodayStudyBlocks";
import ActiveTaskPanel from "@/components/focus/ActiveTaskPanel";
import { emitToast } from "@/components/Toast";
import { useDailyReview } from "@/hooks/useDailyReviews";
import { useUIStore } from "@/stores/uiStore";

export default function FocusPage() {
  const today = format(new Date(), "yyyy-MM-dd");
  const { data: todayReview } = useDailyReview(today);
  const hasShownShutdownNudge = useUIStore((s) => s.hasShownShutdownNudge);
  const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);

  useEffect(() => {
    if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
      emitToast("You've shut down for the day. Rest well!");
      setHasShownShutdownNudge(true);
    }
  }, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);

  return (
    <div className="flex h-full">
      <div className="flex flex-1 flex-col border-r border-[var(--color-border)]">
        <div className="flex-1 overflow-auto">
          <KanbanBoard />
        </div>
        <TodayStudyBlocks />
      </div>
      <div className="w-96 shrink-0">
        <ActiveTaskPanel />
      </div>
    </div>
  );
}

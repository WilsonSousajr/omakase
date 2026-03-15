"use client";

import { useEffect, useRef } from "react";
import KanbanBoard from "@/components/kanban/KanbanBoard";
import TodayStudyBlocks from "@/components/kanban/TodayStudyBlocks";
import ActiveTaskPanel from "@/components/focus/ActiveTaskPanel";
import SessionCompletionModal from "@/components/focus/SessionCompletionModal";
import { emitToast } from "@/components/Toast";
import { useTranslations } from "next-intl";
import { useDailyReview } from "@/hooks/useDailyReviews";
import { useToday } from "@/hooks/useToday";
import { useUIStore } from "@/stores/uiStore";

export default function FocusPage() {
  const t = useTranslations("focus");
  const today = useToday();
  const { data: todayReview } = useDailyReview(today);
  const hasShownShutdownNudge = useUIStore((s) => s.hasShownShutdownNudge);
  const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);
  const sessionCompletionBlock = useUIStore((s) => s.sessionCompletionBlock);
  const setSessionCompletionBlock = useUIStore((s) => s.setSessionCompletionBlock);
  const ratedBlockIds = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
      emitToast(t("shutdownNudge"));
      setHasShownShutdownNudge(true);
    }
  }, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);

  const handleSessionClose = () => {
    if (sessionCompletionBlock) {
      ratedBlockIds.current.add(sessionCompletionBlock.id);
    }
    setSessionCompletionBlock(null);
  };

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

      {sessionCompletionBlock && (
        <SessionCompletionModal
          block={sessionCompletionBlock}
          onClose={handleSessionClose}
        />
      )}
    </div>
  );
}

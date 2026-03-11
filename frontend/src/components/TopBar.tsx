"use client";

import { useState, useEffect } from "react";
import { Plus } from "lucide-react";
import { usePathname } from "next/navigation";
import { useUIStore } from "@/stores/uiStore";
import { useTranslations, useFormatter } from "next-intl";

const TASK_BUTTON_PATHS = ["/plan", "/focus"];

export default function TopBar() {
  const t = useTranslations("topbar");
  const fmt = useFormatter();
  const openModal = useUIStore((s) => s.openModal);
  const pathname = usePathname();
  const [dateStr, setDateStr] = useState("");

  useEffect(() => {
    setDateStr(fmt.dateTime(new Date(), { weekday: "long", month: "long", day: "numeric" }));
  }, [fmt]);

  const showNewTask = TASK_BUTTON_PATHS.some((p) => pathname.startsWith(p));

  return (
    <header className="flex h-12 items-center justify-between bg-[var(--color-bg)] px-4">
      <span className="text-sm text-[var(--color-text-secondary)]">
        {dateStr}
      </span>
      {showNewTask && (
        <button
          onClick={() => openModal("task-form")}
          className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          <Plus className="h-3.5 w-3.5" />
          {t("newTask")}
        </button>
      )}
    </header>
  );
}

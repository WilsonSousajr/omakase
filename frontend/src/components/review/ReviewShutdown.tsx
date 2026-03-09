"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { Moon } from "lucide-react";
import { useUIStore } from "@/stores/uiStore";

interface Props {
  onShutdown: () => Promise<void>;
}

export default function ReviewShutdown({ onShutdown }: Props) {
  const t = useTranslations("review");
  const router = useRouter();
  const setHasShownShutdownNudge = useUIStore(
    (s) => s.setHasShownShutdownNudge
  );
  const [isShuttingDown, setIsShuttingDown] = useState(false);
  const [isDone, setIsDone] = useState(false);

  const handleShutdown = async () => {
    setIsShuttingDown(true);
    try {
      await onShutdown();
      setIsDone(true);
      setHasShownShutdownNudge(false);
    } catch {
      // Error handled by Toast interceptor
    } finally {
      setIsShuttingDown(false);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center space-y-6 py-12 text-center">
      <Moon className="h-10 w-10 text-[var(--color-text-faint)]" />

      {!isDone ? (
        <>
          <div>
            <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
              {t("shutdown.preMessage")}
            </h2>
            <p className="mt-2 text-sm text-[var(--color-text-muted)]">
              {t("shutdown.preSubtitle")}
            </p>
          </div>
          <button
            onClick={handleShutdown}
            disabled={isShuttingDown}
            className="rounded-xl bg-[var(--color-button-primary)] px-8 py-2.5 text-sm font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
          >
            {isShuttingDown ? t("shutdown.shuttingDown") : t("shutdown.shutDown")}
          </button>
        </>
      ) : (
        <>
          <div>
            <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
              {t("shutdown.postMessage")}
            </h2>
          </div>
          <button
            onClick={() => router.push("/plan")}
            className="rounded-xl px-6 py-2 text-xs text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]"
          >
            {t("shutdown.close")}
          </button>
        </>
      )}
    </div>
  );
}

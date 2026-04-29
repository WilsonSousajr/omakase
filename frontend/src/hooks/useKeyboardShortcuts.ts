import { useEffect } from "react";
import { useUIStore } from "@/stores/uiStore";
import { usePomodoroStore } from "@/stores/pomodoroStore";

export function useKeyboardShortcuts() {
  const modalOpen = useUIStore((s) => s.modalOpen);
  const openModal = useUIStore((s) => s.openModal);
  const closeModal = useUIStore((s) => s.closeModal);
  const isRunning = usePomodoroStore((s) => s.isRunning);
  const start = usePomodoroStore((s) => s.start);
  const pause = usePomodoroStore((s) => s.pause);
  const timeRemaining = usePomodoroStore((s) => s.timeRemaining);
  const sessionType = usePomodoroStore((s) => s.sessionType);
  const durations = usePomodoroStore((s) => s.durations);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      const isInput =
        target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.tagName === "SELECT" ||
        target.isContentEditable;

      if (e.key === "Escape") {
        if (modalOpen) closeModal();
        return;
      }

      if (isInput) return;

      if (e.key === "n" || e.key === "N") {
        e.preventDefault();
        openModal("task-form");
      }

      if (e.key === " ") {
        e.preventDefault();
        if (isRunning) {
          pause();
        } else if (timeRemaining < durations[sessionType]) {
          // Only resume a paused session — starting a new session requires
          // the PomodoroTimer's handleStart which creates a backend session
          start();
        }
      }
    };

    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [modalOpen, openModal, closeModal, isRunning, start, pause, timeRemaining, sessionType, durations]);
}

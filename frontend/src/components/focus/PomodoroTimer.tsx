"use client";

import { useEffect, useRef, useCallback } from "react";
import { Pause, Play, RotateCcw } from "lucide-react";
import { cn } from "@/lib/utils";
import { usePomodoroStore } from "@/stores/pomodoroStore";
import { useCreatePomodoroSession, useCompletePomodoroSession } from "@/hooks/usePomodoro";
import { useUIStore } from "@/stores/uiStore";

const SESSION_LABELS = {
  focus: "Focus",
  short_break: "Short Break",
  long_break: "Long Break",
} as const;

const SESSION_COLORS = {
  focus: "text-[#e5e5e5]",
  short_break: "text-[#737373]",
  long_break: "text-[#a3a3a3]",
} as const;

const RING_COLORS = {
  focus: "stroke-[#e5e5e5]",
  short_break: "stroke-[#737373]",
  long_break: "stroke-[#a3a3a3]",
} as const;

const DURATIONS: Record<string, number> = {
  focus: 25 * 60,
  short_break: 5 * 60,
  long_break: 15 * 60,
};

export default function PomodoroTimer() {
  const {
    sessionType,
    timeRemaining,
    isRunning,
    completedPomodoros,
    start,
    pause,
    reset,
    switchSession,
    setOnComplete,
  } = usePomodoroStore();

  const { activeTaskId } = useUIStore();
  const createSession = useCreatePomodoroSession();
  const completeSession = useCompletePomodoroSession();
  const currentSessionId = useRef<string | null>(null);
  const completeSessionRef = useRef(completeSession.mutate);

  useEffect(() => {
    completeSessionRef.current = completeSession.mutate;
  }, [completeSession.mutate]);

  const playNotification = useCallback(() => {
    try {
      const ctx = new AudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.frequency.value = 800;
      gain.gain.value = 0.3;
      osc.start();
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
      osc.stop(ctx.currentTime + 0.5);
    } catch {
      // Audio not available
    }
  }, []);

  useEffect(() => {
    setOnComplete(() => {
      playNotification();
      if (currentSessionId.current) {
        completeSessionRef.current({
          id: currentSessionId.current,
          ended_at: new Date().toISOString(),
        });
        currentSessionId.current = null;
      }
    });
    return () => setOnComplete(null);
  }, [setOnComplete, playNotification]);

  const handleStart = async () => {
    if (!isRunning) {
      const session = await createSession.mutateAsync({
        task: activeTaskId || undefined,
        session_type: sessionType,
        duration_minutes: DURATIONS[sessionType] / 60,
      });
      currentSessionId.current = session.id;
    }
    start();
  };

  const minutes = Math.floor(timeRemaining / 60);
  const seconds = timeRemaining % 60;
  const totalDuration = DURATIONS[sessionType];
  const progress = (totalDuration - timeRemaining) / totalDuration;

  const radius = 80;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - progress * circumference;

  return (
    <div className="flex flex-col items-center">
      {/* Session type tabs */}
      <div className="mb-4 flex rounded-2xl border border-[var(--color-border)]">
        {(["focus", "short_break", "long_break"] as const).map((type) => (
          <button
            key={type}
            onClick={() => switchSession(type)}
            className={cn(
              "px-3 py-1.5 text-xs transition-colors",
              sessionType === type
                ? "bg-[var(--color-surface-hover)] text-[var(--color-text-primary)]"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]"
            )}
          >
            {SESSION_LABELS[type]}
          </button>
        ))}
      </div>

      {/* Circular timer */}
      <div className="relative mb-4">
        <svg width="200" height="200" className="-rotate-90">
          <circle
            cx="100"
            cy="100"
            r={radius}
            fill="none"
            stroke="var(--color-border)"
            strokeWidth="6"
          />
          <circle
            cx="100"
            cy="100"
            r={radius}
            fill="none"
            className={RING_COLORS[sessionType]}
            strokeWidth="6"
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            style={{ transition: "stroke-dashoffset 0.5s ease" }}
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className={cn("text-3xl font-light tabular-nums", SESSION_COLORS[sessionType])}>
            {minutes.toString().padStart(2, "0")}:{seconds.toString().padStart(2, "0")}
          </span>
          <span className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            {SESSION_LABELS[sessionType]}
          </span>
        </div>
      </div>

      {/* Controls */}
      <div className="flex items-center gap-3">
        <button
          onClick={reset}
          className="rounded-full p-2 text-[var(--color-text-faint)] hover:bg-white/5 hover:text-[var(--color-text-secondary)]"
        >
          <RotateCcw className="h-4 w-4" />
        </button>
        <button
          onClick={isRunning ? pause : handleStart}
          className={cn(
            "flex h-12 w-12 items-center justify-center rounded-full transition-colors",
            isRunning
              ? "bg-[var(--color-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
              : "bg-[var(--color-button-primary)] text-[var(--color-button-primary-text)] hover:bg-[var(--color-button-primary-hover)]"
          )}
        >
          {isRunning ? (
            <Pause className="h-5 w-5" />
          ) : (
            <Play className="ml-0.5 h-5 w-5" />
          )}
        </button>
        <div className="w-8 text-center text-xs text-[var(--color-text-muted)]">
          #{completedPomodoros}
        </div>
      </div>
    </div>
  );
}

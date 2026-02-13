"use client";

import { useEffect, useState, useCallback } from "react";
import { X, AlertCircle } from "lucide-react";
import api from "@/lib/api";
import type { AxiosError } from "axios";

interface ToastMessage {
  id: number;
  message: string;
}

let toastId = 0;
const listeners: Set<(msg: ToastMessage) => void> = new Set();

function emitToast(message: string) {
  const msg = { id: ++toastId, message };
  listeners.forEach((fn) => fn(msg));
}

// Set up axios interceptor to catch errors globally
api.interceptors.response.use(
  (res) => res,
  (error: AxiosError) => {
    const message =
      (error.response?.data as { detail?: string })?.detail ||
      error.message ||
      "Something went wrong";
    emitToast(message);
    return Promise.reject(error);
  }
);

export default function Toast() {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const addToast = useCallback((msg: ToastMessage) => {
    setToasts((prev) => [...prev, msg]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== msg.id));
    }, 4000);
  }, []);

  useEffect(() => {
    listeners.add(addToast);
    return () => {
      listeners.delete(addToast);
    };
  }, [addToast]);

  const dismiss = (id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className="flex items-center gap-2 rounded-2xl border border-[#ef4444]/20 bg-[var(--color-surface-elevated)] px-4 py-3 text-sm text-[#ef4444] shadow-lg backdrop-blur"
        >
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span className="flex-1">{toast.message}</span>
          <button
            onClick={() => dismiss(toast.id)}
            className="shrink-0 rounded-lg p-0.5 hover:bg-[#ef4444]/10"
          >
            <X className="h-3 w-3" />
          </button>
        </div>
      ))}
    </div>
  );
}

import { create } from "zustand";
import type { Task } from "@/types/task";

interface UIState {
  sidebarOpen: boolean;
  toggleSidebar: () => void;
  modalOpen: string | null;
  openModal: (id: string) => void;
  closeModal: () => void;
  activeTaskId: string | null;
  setActiveTaskId: (id: string | null) => void;
  editTask: Task | null;
  setEditTask: (task: Task | null) => void;
  activeWorkspaceId: string | null;
  setActiveWorkspaceId: (id: string | null) => void;
  activeSemesterId: string | null;
  setActiveSemesterId: (id: string | null) => void;
  hasShownShutdownNudge: boolean;
  setHasShownShutdownNudge: (value: boolean) => void;
}

export const useUIStore = create<UIState>((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  modalOpen: null,
  openModal: (id) => set({ modalOpen: id }),
  closeModal: () => set({ modalOpen: null }),
  activeTaskId: null,
  setActiveTaskId: (id) => set({ activeTaskId: id }),
  editTask: null,
  setEditTask: (task) => set({ editTask: task }),
  activeWorkspaceId: null,
  setActiveWorkspaceId: (id) => set({ activeWorkspaceId: id }),
  activeSemesterId: null,
  setActiveSemesterId: (id) => set({ activeSemesterId: id }),
  hasShownShutdownNudge: false,
  setHasShownShutdownNudge: (value) => set({ hasShownShutdownNudge: value }),
}));

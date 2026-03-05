import { create } from "zustand";

interface UIState {
  sidebarOpen: boolean;
  toggleSidebar: () => void;
  modalOpen: string | null;
  openModal: (id: string) => void;
  closeModal: () => void;
  activeTaskId: string | null;
  setActiveTaskId: (id: string | null) => void;
  activeWorkspaceId: string | null;
  setActiveWorkspaceId: (id: string | null) => void;
  activeSemesterId: string | null;
  setActiveSemesterId: (id: string | null) => void;
}

export const useUIStore = create<UIState>((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  modalOpen: null,
  openModal: (id) => set({ modalOpen: id }),
  closeModal: () => set({ modalOpen: null }),
  activeTaskId: null,
  setActiveTaskId: (id) => set({ activeTaskId: id }),
  activeWorkspaceId: null,
  setActiveWorkspaceId: (id) => set({ activeWorkspaceId: id }),
  activeSemesterId: null,
  setActiveSemesterId: (id) => set({ activeSemesterId: id }),
}));

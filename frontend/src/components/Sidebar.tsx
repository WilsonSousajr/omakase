"use client";

import { cn } from "@/lib/utils";
import {
  BookOpen,
  Calendar,
  CheckSquare,
  ChevronLeft,
  ChevronRight,
  Crosshair,
  FolderOpen,
  LayoutDashboard,
  Settings,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuthStore } from "@/stores/authStore";
import { useUIStore } from "@/stores/uiStore";
import { useWorkspaces } from "@/hooks/useWorkspaces";
import { useSemesters } from "@/hooks/useSemesters";
import SidebarStats from "./SidebarStats";
import UserAvatar from "./UserAvatar";

const NAV_ITEMS = [
  { href: "/plan", label: "Plan", icon: Calendar },
  { href: "/focus", label: "Focus", icon: Crosshair },
  { href: "/review", label: "Review", icon: CheckSquare },
  { href: "/projects", label: "Projects", icon: FolderOpen },
  { href: "/study", label: "Study", icon: BookOpen },
];

export default function Sidebar() {
  const pathname = usePathname();
  const sidebarOpen = useUIStore((s) => s.sidebarOpen);
  const toggleSidebar = useUIStore((s) => s.toggleSidebar);
  const activeWorkspaceId = useUIStore((s) => s.activeWorkspaceId);
  const setActiveWorkspaceId = useUIStore((s) => s.setActiveWorkspaceId);
  const activeSemesterId = useUIStore((s) => s.activeSemesterId);
  const setActiveSemesterId = useUIStore((s) => s.setActiveSemesterId);
  const user = useAuthStore((s) => s.user);
  const { data: workspaces = [] } = useWorkspaces();
  const { data: semesters = [] } = useSemesters();

  return (
    <aside
      className={cn(
        "flex flex-col border-r border-[var(--color-border)] bg-[var(--color-bg)] transition-all duration-200",
        sidebarOpen ? "w-48" : "w-14"
      )}
    >
      <div className="flex items-center border-b border-[var(--color-border)] p-3">
        {sidebarOpen ? (
          <>
            <LayoutDashboard className="h-5 w-5 shrink-0 text-[var(--color-text-secondary)]" />
            <span className="ml-2 text-sm font-semibold text-[var(--color-text-primary)]">Omakase</span>
            <button
              onClick={toggleSidebar}
              className="ml-auto rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
          </>
        ) : (
          <button
            onClick={toggleSidebar}
            className="mx-auto rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        )}
      </div>

      {sidebarOpen && workspaces.length > 0 && (
        <div className="border-b border-[var(--color-border)] px-3 py-2">
          <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Workspace
          </label>
          <select
            value={activeWorkspaceId || ""}
            onChange={(e) => setActiveWorkspaceId(e.target.value || null)}
            className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">All workspaces</option>
            {workspaces.map((ws) => (
              <option key={ws.id} value={ws.id}>
                {ws.name}
              </option>
            ))}
          </select>
        </div>
      )}

      {sidebarOpen && semesters.length > 0 && (
        <div className="border-b border-[var(--color-border)] px-3 py-2">
          <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Semester
          </label>
          <select
            value={activeSemesterId || ""}
            onChange={(e) => setActiveSemesterId(e.target.value || null)}
            className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">All semesters</option>
            {semesters.map((sem) => (
              <option key={sem.id} value={sem.id}>
                {sem.name}
              </option>
            ))}
          </select>
        </div>
      )}

      <nav className="flex flex-col gap-1 p-2">
        {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
          const active = pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                "flex items-center gap-2 rounded-xl px-2.5 py-2 text-sm transition-colors",
                active
                  ? "bg-[var(--color-surface-active)] text-[var(--color-text-primary)]"
                  : "text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {sidebarOpen && <span>{label}</span>}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto">
        {user && (
          <Link
            href="/settings"
            className={cn(
              "flex items-center border-t border-[var(--color-border)] transition-colors hover:bg-[var(--color-surface)]",
              sidebarOpen ? "gap-2 px-3 py-2.5" : "justify-center py-2.5"
            )}
          >
            <UserAvatar user={user} size={sidebarOpen ? "md" : "sm"} />
            {sidebarOpen && (
              <>
                <span className="flex-1 truncate text-xs text-[var(--color-text-secondary)]">
                  {user.username}
                </span>
                <Settings className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-faint)]" />
              </>
            )}
          </Link>
        )}
        {sidebarOpen && <SidebarStats />}
      </div>
    </aside>
  );
}

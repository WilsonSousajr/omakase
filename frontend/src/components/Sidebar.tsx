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
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useUIStore } from "@/stores/uiStore";
import { useWorkspaces } from "@/hooks/useWorkspaces";
import { useSemesters } from "@/hooks/useSemesters";
import { useTranslations } from "next-intl";
import SidebarStats from "./SidebarStats";
import ThemeToggle from "./ThemeToggle";
import LocaleSwitcher from "./LocaleSwitcher";

const NAV_ITEMS = [
  { href: "/plan", label: "plan", icon: Calendar },
  { href: "/focus", label: "focus", icon: Crosshair },
  { href: "/review", label: "review", icon: CheckSquare },
  { href: "/projects", label: "projects", icon: FolderOpen },
  { href: "/study", label: "study", icon: BookOpen },
];

export default function Sidebar() {
  const t = useTranslations("sidebar");
  const pathname = usePathname();
  const sidebarOpen = useUIStore((s) => s.sidebarOpen);
  const toggleSidebar = useUIStore((s) => s.toggleSidebar);
  const activeWorkspaceId = useUIStore((s) => s.activeWorkspaceId);
  const setActiveWorkspaceId = useUIStore((s) => s.setActiveWorkspaceId);
  const activeSemesterId = useUIStore((s) => s.activeSemesterId);
  const setActiveSemesterId = useUIStore((s) => s.setActiveSemesterId);
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
            {t("workspace")}
          </label>
          <select
            value={activeWorkspaceId || ""}
            onChange={(e) => setActiveWorkspaceId(e.target.value || null)}
            className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">{t("allWorkspaces")}</option>
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
            {t("semester")}
          </label>
          <select
            value={activeSemesterId || ""}
            onChange={(e) => setActiveSemesterId(e.target.value || null)}
            className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">{t("allSemesters")}</option>
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
              {sidebarOpen && <span>{t(label)}</span>}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto">
        {sidebarOpen && <SidebarStats />}
        <div
          className={cn(
            "flex items-center border-t border-[var(--color-border)] px-2 py-2",
            sidebarOpen ? "justify-end" : "justify-center"
          )}
        >
          <LocaleSwitcher />
          <ThemeToggle />
        </div>
      </div>
    </aside>
  );
}

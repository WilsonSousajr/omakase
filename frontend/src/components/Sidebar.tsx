"use client";

import { cn } from "@/lib/utils";
import {
  Calendar,
  ChevronLeft,
  ChevronRight,
  Crosshair,
  LayoutDashboard,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useUIStore } from "@/stores/uiStore";

const NAV_ITEMS = [
  { href: "/plan", label: "Plan", icon: Calendar },
  { href: "/focus", label: "Focus", icon: Crosshair },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { sidebarOpen, toggleSidebar } = useUIStore();

  return (
    <aside
      className={cn(
        "flex flex-col border-r border-[var(--color-border)] bg-[var(--color-bg)] transition-all duration-200",
        sidebarOpen ? "w-48" : "w-14"
      )}
    >
      <div className="flex items-center gap-2 border-b border-[var(--color-border)] p-3">
        <LayoutDashboard className="h-5 w-5 shrink-0 text-[var(--color-text-secondary)]" />
        {sidebarOpen && (
          <span className="text-sm font-semibold text-[var(--color-text-primary)]">Omakase</span>
        )}
        <button
          onClick={toggleSidebar}
          className="ml-auto rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
        >
          {sidebarOpen ? (
            <ChevronLeft className="h-4 w-4" />
          ) : (
            <ChevronRight className="h-4 w-4" />
          )}
        </button>
      </div>

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
                  ? "bg-white/8 text-[var(--color-text-primary)]"
                  : "text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {sidebarOpen && <span>{label}</span>}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}

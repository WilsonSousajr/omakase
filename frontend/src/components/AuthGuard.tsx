"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { useMe } from "@/hooks/useAuth";
import { useAuthStore } from "@/stores/authStore";

const PUBLIC_PATHS = ["/login", "/register"];

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const [hasMounted, setHasMounted] = useState(false);
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const router = useRouter();
  const pathname = usePathname();
  const { isLoading } = useMe();

  useEffect(() => {
    setHasMounted(true);
  }, []);

  useEffect(() => {
    if (hasMounted && !isAuthenticated && !PUBLIC_PATHS.includes(pathname)) {
      router.replace("/login");
    }
  }, [hasMounted, isAuthenticated, pathname, router]);

  // Before hydration, render a neutral loading state that matches on server and client
  if (!hasMounted) {
    return (
      <div className="flex h-screen items-center justify-center bg-[var(--color-bg)]">
        <div className="text-sm text-[var(--color-text-muted)]">Loading...</div>
      </div>
    );
  }

  if (!isAuthenticated && !PUBLIC_PATHS.includes(pathname)) {
    return null;
  }

  if (isAuthenticated && isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-[var(--color-bg)]">
        <div className="text-sm text-[var(--color-text-muted)]">Loading...</div>
      </div>
    );
  }

  return <>{children}</>;
}

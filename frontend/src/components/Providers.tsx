"use client";

import { GoogleOAuthProvider } from "@react-oauth/google";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ThemeProvider } from "next-themes";
import { NextIntlClientProvider } from "next-intl";
import { useEffect, useState } from "react";
import { useLocaleStore } from "@/stores/localeStore";
import { getMessages } from "@/i18n/getMessages";
import type { Locale } from "@/i18n/config";
import { defaultLocale } from "@/i18n/config";

function IntlProvider({ children }: { children: React.ReactNode }) {
  const locale = useLocaleStore((s) => s.locale);
  const [mounted, setMounted] = useState(false);
  const [messages, setMessages] = useState<Record<string, unknown> | null>(null);
  const [activeLocale, setActiveLocale] = useState<Locale>(defaultLocale);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    const target = mounted ? locale : defaultLocale;
    getMessages(target).then((msgs) => {
      setMessages(msgs);
      setActiveLocale(target);
    });
  }, [locale, mounted]);

  if (!messages) return null;

  return (
    <NextIntlClientProvider locale={activeLocale} messages={messages} timeZone={Intl.DateTimeFormat().resolvedOptions().timeZone}>
      {children}
    </NextIntlClientProvider>
  );
}

export default function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30 * 1000,
            refetchOnWindowFocus: false,
          },
        },
      })
  );

  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || "";

  return (
    <GoogleOAuthProvider clientId={googleClientId}>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          storageKey="omakase-theme"
        >
          <IntlProvider>{children}</IntlProvider>
        </ThemeProvider>
      </QueryClientProvider>
    </GoogleOAuthProvider>
  );
}

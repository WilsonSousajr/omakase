import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach, vi } from "vitest";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

// Mock next-themes
vi.mock("next-themes", () => ({
  useTheme: () => ({
    theme: "dark",
    setTheme: vi.fn(),
    resolvedTheme: "dark",
  }),
  ThemeProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock next-intl — uses real English messages so tests assert on actual text
// eslint-disable-next-line @typescript-eslint/no-require-imports
const messages = require("../../messages/en.json");

function resolve(obj: Record<string, unknown>, path: string): unknown {
  return path.split(".").reduce((acc: unknown, part) => {
    if (acc && typeof acc === "object") return (acc as Record<string, unknown>)[part];
    return undefined;
  }, obj);
}

vi.mock("next-intl", () => ({
  useTranslations: (namespace?: string) => {
    const nsObj = namespace ? resolve(messages, namespace) : messages;
    const t = (key: string, params?: Record<string, unknown>) => {
      const val = resolve(nsObj as Record<string, unknown>, key);
      if (typeof val !== "string") return namespace ? `${namespace}.${key}` : key;
      if (params) {
        return Object.entries(params).reduce(
          (str, [k, v]) => str.replace(`{${k}}`, String(v)),
          val,
        );
      }
      return val;
    };
    t.rich = t;
    t.raw = (key: string) => {
      const val = resolve(nsObj as Record<string, unknown>, key);
      return val ?? (namespace ? `${namespace}.${key}` : key);
    };
    return t;
  },
  useFormatter: () => ({
    dateTime: (date: Date, options?: Intl.DateTimeFormatOptions) =>
      new Intl.DateTimeFormat("en-US", options).format(date),
    number: (n: number) => String(n),
  }),
  useLocale: () => "en",
  NextIntlClientProvider: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock @react-oauth/google
vi.mock("@react-oauth/google", () => ({
  GoogleOAuthProvider: ({ children }: { children: unknown }) => children,
  GoogleLogin: () => null,
}));

// Mock next/navigation
vi.mock("next/navigation", () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
    prefetch: vi.fn(),
  }),
  usePathname: () => "/plan",
  useSearchParams: () => new URLSearchParams(),
}));

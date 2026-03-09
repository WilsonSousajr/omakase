import { create } from "zustand";
import type { Locale } from "@/i18n/config";
import { defaultLocale } from "@/i18n/config";

interface LocaleState {
  locale: Locale;
  setLocale: (locale: Locale) => void;
}

function loadLocale(): Locale {
  try {
    if (typeof window === "undefined") return defaultLocale;
    const stored = localStorage.getItem("omakase-locale");
    if (stored === "pt-BR") return "pt-BR";
    return defaultLocale;
  } catch {
    return defaultLocale;
  }
}

function saveLocale(locale: Locale) {
  try {
    if (typeof window === "undefined") return;
    localStorage.setItem("omakase-locale", locale);
  } catch {
    // localStorage may not be available
  }
}

export const useLocaleStore = create<LocaleState>((set) => ({
  locale: loadLocale(),
  setLocale: (locale) => {
    saveLocale(locale);
    set({ locale });
  },
}));

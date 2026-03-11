"use client";

import { useTranslations } from "next-intl";
import { useLocaleStore } from "@/stores/localeStore";

const LOCALE_CYCLE = { en: "pt-BR", "pt-BR": "en" } as const;
const LOCALE_LABELS = { en: "EN", "pt-BR": "PT" } as const;

export default function LocaleSwitcher() {
  const t = useTranslations("accessibility");
  const locale = useLocaleStore((s) => s.locale);
  const setLocale = useLocaleStore((s) => s.setLocale);

  return (
    <button
      aria-label={t("toggleLanguage")}
      onClick={() => setLocale(LOCALE_CYCLE[locale])}
      className="rounded-lg px-1.5 py-1 text-[10px] font-semibold text-[var(--color-text-faint)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
    >
      {LOCALE_LABELS[locale]}
    </button>
  );
}

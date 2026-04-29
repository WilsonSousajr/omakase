"use client";

import { useTranslations } from "next-intl";
import { COLOR_PRESETS } from "@/lib/constants";

interface ColorSwatchPickerProps {
  value: string;
  onChange: (color: string) => void;
}

export default function ColorSwatchPicker({ value, onChange }: ColorSwatchPickerProps) {
  const t = useTranslations("common");
  return (
    <div>
      <label className="mb-1.5 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
        {t("color")}
      </label>
      <div className="flex flex-wrap gap-2">
        {COLOR_PRESETS.map((preset) => (
          <button
            key={preset.value}
            type="button"
            title={preset.label}
            onClick={() => onChange(preset.value)}
            className={`h-6 w-6 rounded-full transition-transform hover:scale-110 ${
              value === preset.value
                ? "ring-2 ring-[var(--color-text-primary)] ring-offset-2 ring-offset-[var(--color-surface-elevated)]"
                : ""
            }`}
            style={{ backgroundColor: preset.value }}
          />
        ))}
      </div>
    </div>
  );
}

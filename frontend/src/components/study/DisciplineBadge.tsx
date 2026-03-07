"use client";

import { BookOpen } from "lucide-react";

interface DisciplineBadgeProps {
  name: string;
  color: string;
}

export default function DisciplineBadge({ name, color }: DisciplineBadgeProps) {
  return (
    <span
      className="flex items-center gap-1 rounded-lg px-1.5 py-0.5 text-[10px]"
      style={{
        backgroundColor: color + "20",
        color: color,
      }}
    >
      <BookOpen className="h-2.5 w-2.5" />
      {name}
    </span>
  );
}

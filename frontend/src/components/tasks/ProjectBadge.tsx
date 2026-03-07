"use client";

import { FolderOpen } from "lucide-react";

interface ProjectBadgeProps {
  name: string;
  color: string;
}

export default function ProjectBadge({ name, color }: ProjectBadgeProps) {
  return (
    <span
      className="flex items-center gap-1 rounded-lg px-1.5 py-0.5 text-[10px]"
      style={{
        backgroundColor: color + "20",
        color: color,
      }}
    >
      <FolderOpen className="h-2.5 w-2.5" />
      {name}
    </span>
  );
}

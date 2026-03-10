import React from "react";
import { cn } from "@/lib/utils";
import type { User } from "@/types/auth";

interface UserAvatarProps {
  user: User;
  size?: "sm" | "md" | "lg";
}

const SIZE_CLASSES = {
  sm: "h-7 w-7 text-[10px]",
  md: "h-8 w-8 text-xs",
  lg: "h-16 w-16 text-xl",
} as const;

export function getInitials(user: User): string {
  if (user.first_name && user.last_name) {
    return (user.first_name[0] + user.last_name[0]).toUpperCase();
  }
  if (user.first_name) {
    return user.first_name.slice(0, 2).toUpperCase();
  }
  return user.username.slice(0, 2).toUpperCase();
}

const UserAvatar = React.memo(function UserAvatar({
  user,
  size = "md",
}: UserAvatarProps) {
  return (
    <div
      className={cn(
        "flex shrink-0 items-center justify-center rounded-full font-semibold text-white",
        SIZE_CLASSES[size]
      )}
      style={{ backgroundColor: user.avatar_color }}
    >
      {getInitials(user)}
    </div>
  );
});

export default UserAvatar;

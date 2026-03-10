import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { createMockUser } from "@/test/handlers";
import UserAvatar, { getInitials } from "../UserAvatar";

describe("getInitials", () => {
  it("returns first+last initials when both names exist", () => {
    const user = createMockUser({ first_name: "John", last_name: "Doe" });
    expect(getInitials(user)).toBe("JD");
  });

  it("returns first two chars of first_name when no last_name", () => {
    const user = createMockUser({ first_name: "John", last_name: "" });
    expect(getInitials(user)).toBe("JO");
  });

  it("returns first two chars of username as fallback", () => {
    const user = createMockUser({ first_name: "", last_name: "" });
    expect(getInitials(user)).toBe("TE");
  });

  it("uppercases initials", () => {
    const user = createMockUser({ first_name: "john", last_name: "doe" });
    expect(getInitials(user)).toBe("JD");
  });

  it("handles single-char first_name with no last_name", () => {
    const user = createMockUser({ first_name: "J", last_name: "" });
    expect(getInitials(user)).toBe("J");
  });
});

describe("UserAvatar", () => {
  it("renders initials", () => {
    const user = createMockUser({ first_name: "John", last_name: "Doe" });
    render(<UserAvatar user={user} />);
    expect(screen.getByText("JD")).toBeInTheDocument();
  });

  it("applies avatar color as background", () => {
    const user = createMockUser({ avatar_color: "#ff5733" });
    render(<UserAvatar user={user} />);
    const avatar = screen.getByText("TE");
    expect(avatar).toHaveStyle({ backgroundColor: "#ff5733" });
  });

  it("renders sm size", () => {
    const user = createMockUser();
    render(<UserAvatar user={user} size="sm" />);
    const avatar = screen.getByText("TE");
    expect(avatar.className).toContain("h-7");
    expect(avatar.className).toContain("w-7");
  });

  it("renders lg size", () => {
    const user = createMockUser();
    render(<UserAvatar user={user} size="lg" />);
    const avatar = screen.getByText("TE");
    expect(avatar.className).toContain("h-16");
    expect(avatar.className).toContain("w-16");
  });

  it("defaults to md size", () => {
    const user = createMockUser();
    render(<UserAvatar user={user} />);
    const avatar = screen.getByText("TE");
    expect(avatar.className).toContain("h-8");
    expect(avatar.className).toContain("w-8");
  });
});

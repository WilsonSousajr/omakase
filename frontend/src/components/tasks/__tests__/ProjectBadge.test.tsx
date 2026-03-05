import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import ProjectBadge from "../ProjectBadge";

describe("ProjectBadge", () => {
  it("renders project name", () => {
    render(<ProjectBadge name="My Project" color="#f59e0b" />);
    expect(screen.getByText("My Project")).toBeInTheDocument();
  });

  it("applies color styling", () => {
    render(<ProjectBadge name="Colored" color="#ff6600" />);
    const badge = screen.getByText("Colored").closest("span")!;
    // jsdom normalizes hex to rgb
    expect(badge.style.color).toBe("rgb(255, 102, 0)");
    expect(badge.style.backgroundColor).toContain("rgba(255, 102, 0");
  });

  it("renders FolderOpen icon", () => {
    const { container } = render(<ProjectBadge name="Icon" color="#aaa" />);
    const svg = container.querySelector("svg");
    expect(svg).toBeInTheDocument();
  });
});

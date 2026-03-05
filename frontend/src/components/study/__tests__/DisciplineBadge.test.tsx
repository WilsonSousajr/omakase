import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import DisciplineBadge from "../DisciplineBadge";

describe("DisciplineBadge", () => {
  it("renders discipline name", () => {
    render(<DisciplineBadge name="Calculus II" color="#3b82f6" />);
    expect(screen.getByText("Calculus II")).toBeInTheDocument();
  });

  it("applies color styling", () => {
    render(<DisciplineBadge name="Colored" color="#ff6600" />);
    const badge = screen.getByText("Colored").closest("span")!;
    // jsdom normalizes hex to rgb
    expect(badge.style.color).toBe("rgb(255, 102, 0)");
    expect(badge.style.backgroundColor).toContain("rgba(255, 102, 0");
  });

  it("renders BookOpen icon", () => {
    const { container } = render(<DisciplineBadge name="Icon" color="#aaa" />);
    const svg = container.querySelector("svg");
    expect(svg).toBeInTheDocument();
  });
});

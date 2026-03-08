import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

const mockSetTheme = vi.fn();
let mockTheme = "system";

vi.mock("next-themes", () => ({
  useTheme: () => ({
    theme: mockTheme,
    setTheme: mockSetTheme,
  }),
}));

import ThemeToggle from "../ThemeToggle";

describe("ThemeToggle", () => {
  beforeEach(() => {
    mockTheme = "system";
    mockSetTheme.mockClear();
  });

  it("renders a button", () => {
    render(<ThemeToggle />);
    expect(screen.getByRole("button", { name: /theme/i })).toBeInTheDocument();
  });

  it("shows Monitor icon when theme is system", () => {
    mockTheme = "system";
    render(<ThemeToggle />);
    const button = screen.getByRole("button", { name: /theme/i });
    expect(button.querySelector("svg")).toBeInTheDocument();
  });

  it("cycles from system to light", () => {
    mockTheme = "system";
    render(<ThemeToggle />);
    fireEvent.click(screen.getByRole("button", { name: /theme/i }));
    expect(mockSetTheme).toHaveBeenCalledWith("light");
  });

  it("cycles from light to dark", () => {
    mockTheme = "light";
    render(<ThemeToggle />);
    fireEvent.click(screen.getByRole("button", { name: /theme/i }));
    expect(mockSetTheme).toHaveBeenCalledWith("dark");
  });

  it("cycles from dark to system", () => {
    mockTheme = "dark";
    render(<ThemeToggle />);
    fireEvent.click(screen.getByRole("button", { name: /theme/i }));
    expect(mockSetTheme).toHaveBeenCalledWith("system");
  });
});

import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import ReviewScore from "../ReviewScore";

describe("ReviewScore", () => {
  it("renders 5 rating buttons", () => {
    render(<ReviewScore rating={null} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("1")).toBeInTheDocument();
    expect(screen.getByText("5")).toBeInTheDocument();
  });

  it("calls onRate when button clicked", async () => {
    const onRate = vi.fn();
    render(<ReviewScore rating={null} onRate={onRate} onNext={vi.fn()} />);
    await userEvent.click(screen.getByText("4"));
    expect(onRate).toHaveBeenCalledWith(4);
  });

  it("disables Continue when no rating", () => {
    render(<ReviewScore rating={null} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("Continue")).toBeDisabled();
  });

  it("enables Continue when rated", () => {
    render(<ReviewScore rating={3} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("Continue")).not.toBeDisabled();
  });
});

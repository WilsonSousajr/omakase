import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import ReviewShutdown from "../ReviewShutdown";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

describe("ReviewShutdown", () => {
  it("renders shutdown prompt", () => {
    render(<ReviewShutdown onShutdown={vi.fn()} />);
    expect(screen.getByText("Ready to shut down?")).toBeInTheDocument();
    expect(screen.getByText("Shut Down")).toBeInTheDocument();
  });

  it("calls onShutdown and shows completion", async () => {
    const onShutdown = vi.fn().mockResolvedValue(undefined);
    render(<ReviewShutdown onShutdown={onShutdown} />);
    await userEvent.click(screen.getByText("Shut Down"));
    expect(onShutdown).toHaveBeenCalledOnce();
    expect(
      screen.getByText("Great work today. Time to rest.")
    ).toBeInTheDocument();
  });
});

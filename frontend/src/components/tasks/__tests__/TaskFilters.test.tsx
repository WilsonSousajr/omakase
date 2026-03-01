import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import TaskFilters from "../TaskFilters";

describe("TaskFilters", () => {
  const defaultProps = {
    search: "",
    onSearchChange: vi.fn(),
    priority: "",
    onPriorityChange: vi.fn(),
  };

  it("renders search input with placeholder", () => {
    render(<TaskFilters {...defaultProps} />);
    expect(screen.getByPlaceholderText("Search tasks...")).toBeInTheDocument();
  });

  it("renders priority select with all options", () => {
    render(<TaskFilters {...defaultProps} />);
    const options = screen.getAllByRole("option");
    expect(options).toHaveLength(5);
    expect(options[0]).toHaveTextContent("All priorities");
    expect(options[1]).toHaveTextContent("Low");
    expect(options[2]).toHaveTextContent("Medium");
    expect(options[3]).toHaveTextContent("High");
    expect(options[4]).toHaveTextContent("Urgent");
  });

  it("search input fires onSearchChange", () => {
    const onSearchChange = vi.fn();
    render(<TaskFilters {...defaultProps} onSearchChange={onSearchChange} />);

    const input = screen.getByPlaceholderText("Search tasks...");
    fireEvent.change(input, { target: { value: "deploy" } });
    expect(onSearchChange).toHaveBeenCalledWith("deploy");
  });

  it("priority select fires onPriorityChange", () => {
    const onPriorityChange = vi.fn();
    render(<TaskFilters {...defaultProps} onPriorityChange={onPriorityChange} />);

    const select = screen.getByRole("combobox");
    fireEvent.change(select, { target: { value: "urgent" } });
    expect(onPriorityChange).toHaveBeenCalledWith("urgent");
  });

  it("controlled search value", () => {
    render(<TaskFilters {...defaultProps} search="hello" />);

    const input = screen.getByPlaceholderText("Search tasks...");
    expect(input).toHaveValue("hello");
  });

  it("controlled priority value", () => {
    render(<TaskFilters {...defaultProps} priority="high" />);

    const select = screen.getByRole("combobox");
    expect(select).toHaveValue("high");
  });
});

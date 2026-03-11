import { render, screen, fireEvent } from "@testing-library/react";
import { describe, expect, it, vi, beforeEach } from "vitest";

vi.mock("@/stores/localeStore", () => {
  let locale = "en";
  const setLocale = vi.fn((newLocale: string) => {
    locale = newLocale;
  });
  return {
    useLocaleStore: (selector: (s: { locale: string; setLocale: typeof setLocale }) => unknown) =>
      selector({ locale, setLocale }),
    _reset: () => {
      locale = "en";
      setLocale.mockClear();
    },
    _getSetLocale: () => setLocale,
  };
});

import LocaleSwitcher from "../LocaleSwitcher";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const mod = await import("@/stores/localeStore") as any;

describe("LocaleSwitcher", () => {
  beforeEach(() => {
    mod._reset();
  });

  it("renders a button with current locale", () => {
    render(<LocaleSwitcher />);
    expect(screen.getByRole("button", { name: /language/i })).toBeInTheDocument();
    expect(screen.getByText("EN")).toBeInTheDocument();
  });

  it("calls setLocale when clicked", () => {
    render(<LocaleSwitcher />);
    fireEvent.click(screen.getByRole("button", { name: /language/i }));
    expect(mod._getSetLocale()).toHaveBeenCalledWith("pt-BR");
  });
});

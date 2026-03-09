import { describe, it, expect, beforeEach, vi } from "vitest";

const mockStorage: Record<string, string> = {};
vi.stubGlobal("localStorage", {
  getItem: (key: string) => mockStorage[key] ?? null,
  setItem: (key: string, value: string) => {
    mockStorage[key] = value;
  },
  removeItem: (key: string) => {
    delete mockStorage[key];
  },
});

// Must import after stubbing localStorage
const { useLocaleStore } = await import("../localeStore");

describe("localeStore", () => {
  beforeEach(() => {
    Object.keys(mockStorage).forEach((k) => delete mockStorage[k]);
    useLocaleStore.setState({ locale: "en" });
  });

  it("defaults to 'en'", () => {
    expect(useLocaleStore.getState().locale).toBe("en");
  });

  it("setLocale updates to pt-BR", () => {
    useLocaleStore.getState().setLocale("pt-BR");
    expect(useLocaleStore.getState().locale).toBe("pt-BR");
  });

  it("persists locale to localStorage", () => {
    useLocaleStore.getState().setLocale("pt-BR");
    expect(mockStorage["omakase-locale"]).toBe("pt-BR");
  });

  it("loads locale from localStorage on init", async () => {
    mockStorage["omakase-locale"] = "pt-BR";
    // Re-import to trigger loadLocale
    vi.resetModules();
    const { useLocaleStore: freshStore } = await import("../localeStore");
    expect(freshStore.getState().locale).toBe("pt-BR");
  });
});

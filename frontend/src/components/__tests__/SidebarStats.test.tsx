import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { screen } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { renderWithProviders } from "@/test/utils";
import { handlers, createMockDailyStats } from "@/test/handlers";
import SidebarStats from "../SidebarStats";

const server = setupServer(...handlers);
const API_URL = "http://localhost:8000/api/v1";

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe("SidebarStats", () => {
  it("renders stats when data is loaded", async () => {
    renderWithProviders(<SidebarStats />);

    expect(await screen.findByText("2.5h focused")).toBeInTheDocument();
    expect(screen.getByText("3/5 blocks")).toBeInTheDocument();
    expect(screen.getByText("7d streak")).toBeInTheDocument();
  });

  it("renders weekly hours breakdown", async () => {
    renderWithProviders(<SidebarStats />);

    expect(await screen.findByText("Work")).toBeInTheDocument();
    expect(screen.getByText("12h")).toBeInTheDocument();
    expect(screen.getByText("Study")).toBeInTheDocument();
    expect(screen.getByText("4.5h")).toBeInTheDocument();
  });

  it("hides streak when zero", async () => {
    server.use(
      http.get(`${API_URL}/stats/daily/`, () =>
        HttpResponse.json(createMockDailyStats({
          hours_focused_today: 1.0,
          blocks_completed_today: 1,
          blocks_total_today: 2,
          current_streak: 0,
          weekly_work_hours: 5.0,
        }))
      )
    );
    renderWithProviders(<SidebarStats />);

    expect(await screen.findByText("1h focused")).toBeInTheDocument();
    expect(screen.queryByText(/streak/)).not.toBeInTheDocument();
  });

  it("hides weekly section when no hours", async () => {
    server.use(
      http.get(`${API_URL}/stats/daily/`, () =>
        HttpResponse.json(createMockDailyStats({
          hours_focused_today: 0.5,
          blocks_completed_today: 0,
          blocks_total_today: 1,
          current_streak: 1,
          weekly_work_hours: 0,
          weekly_study_hours: 0,
        }))
      )
    );
    renderWithProviders(<SidebarStats />);

    expect(await screen.findByText("0.5h focused")).toBeInTheDocument();
    expect(screen.queryByText("This Week")).not.toBeInTheDocument();
  });

  it("renders nothing while loading", () => {
    server.use(
      http.get(`${API_URL}/stats/daily/`, () =>
        new Promise(() => {})  // never resolves
      )
    );
    const { container } = renderWithProviders(<SidebarStats />);
    expect(container.innerHTML).toBe("");
  });

  it("shows section labels with correct styling", async () => {
    renderWithProviders(<SidebarStats />);

    const todayLabel = await screen.findByText("Today");
    expect(todayLabel).toBeInTheDocument();
    expect(todayLabel.tagName).toBe("P");
  });
});

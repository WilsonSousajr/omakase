import { screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import ReviewHistory from "../ReviewHistory";
import { renderWithProviders } from "@/test/utils";
import { handlers, createMockDailyReview } from "@/test/handlers";

const API_URL = "http://localhost:8000/api/v1";
const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function paginated<T>(results: T[], next: string | null = null) {
  return { count: results.length, next, previous: null, results };
}

describe("ReviewHistory", () => {
  it("renders empty state when no reviews", async () => {
    server.use(
      http.get(`${API_URL}/stats/reviews/`, () =>
        HttpResponse.json(paginated([]))
      )
    );
    renderWithProviders(<ReviewHistory />);
    await waitFor(() => {
      expect(screen.getByText("No past reviews yet")).toBeInTheDocument();
    });
  });

  it("renders review cards when data exists", async () => {
    renderWithProviders(<ReviewHistory />);
    await waitFor(() => {
      expect(screen.getByText("Friday, March 6")).toBeInTheDocument();
    });
    expect(screen.getByText("Thursday, March 5")).toBeInTheDocument();
  });

  it("shows Load more button when next page exists", async () => {
    server.use(
      http.get(`${API_URL}/stats/reviews/`, () =>
        HttpResponse.json(
          paginated(
            [createMockDailyReview({ date: "2026-03-06" })],
            `${API_URL}/stats/reviews/?page=2`
          )
        )
      )
    );
    renderWithProviders(<ReviewHistory />);
    await waitFor(() => {
      expect(screen.getByText("Load more")).toBeInTheDocument();
    });
  });

  it("hides Load more when no next page", async () => {
    renderWithProviders(<ReviewHistory />);
    await waitFor(() => {
      expect(screen.getByText("Friday, March 6")).toBeInTheDocument();
    });
    expect(screen.queryByText("Load more")).not.toBeInTheDocument();
  });
});

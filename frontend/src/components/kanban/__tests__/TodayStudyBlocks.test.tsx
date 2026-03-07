import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { renderWithProviders } from "@/test/utils";
import { handlers, createMockStudyBlock, createMockDiscipline } from "@/test/handlers";
import TodayStudyBlocks from "../TodayStudyBlocks";

const API_URL = "http://localhost:8000/api/v1";
const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

function paginated(results: unknown[]) {
  return { count: results.length, next: null, previous: null, results };
}

describe("TodayStudyBlocks", () => {
  it("renders nothing when no study blocks scheduled", async () => {
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, () =>
        HttpResponse.json(paginated([]))
      )
    );
    const { container } = renderWithProviders(<TodayStudyBlocks />);
    // Component returns null when empty
    await waitFor(() => {
      expect(container.innerHTML).toBe("");
    });
  });

  it("renders study blocks with titles", async () => {
    const discId = "disc-123";
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, () =>
        HttpResponse.json(paginated([
          createMockStudyBlock({ title: "Review Chapter 5", discipline: discId }),
          createMockStudyBlock({ title: "Problem Set 3", discipline: discId }),
        ]))
      ),
      http.get(`${API_URL}/study/disciplines/`, () =>
        HttpResponse.json(paginated([
          createMockDiscipline({ id: discId, name: "Calculus II", color: "#3b82f6" }),
        ]))
      ),
    );

    renderWithProviders(<TodayStudyBlocks />);

    await waitFor(() => {
      expect(screen.getByText("Review Chapter 5")).toBeInTheDocument();
      expect(screen.getByText("Problem Set 3")).toBeInTheDocument();
    });
  });

  it("shows study block count badge", async () => {
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, () =>
        HttpResponse.json(paginated([
          createMockStudyBlock({ title: "Block 1" }),
        ]))
      ),
    );

    renderWithProviders(<TodayStudyBlocks />);

    await waitFor(() => {
      expect(screen.getByText("1")).toBeInTheDocument();
      expect(screen.getByText("Today's Study Blocks")).toBeInTheDocument();
    });
  });

  it("shows discipline badge when available", async () => {
    const discId = "disc-456";
    server.use(
      http.get(`${API_URL}/study/studyblocks/`, () =>
        HttpResponse.json(paginated([
          createMockStudyBlock({ title: "Test", discipline: discId }),
        ]))
      ),
      http.get(`${API_URL}/study/disciplines/`, () =>
        HttpResponse.json(paginated([
          createMockDiscipline({ id: discId, name: "Physics I" }),
        ]))
      ),
    );

    renderWithProviders(<TodayStudyBlocks />);

    await waitFor(() => {
      expect(screen.getByText("Physics I")).toBeInTheDocument();
    });
  });
});

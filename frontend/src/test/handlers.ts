import { http, HttpResponse } from "msw";

const API_URL = "http://localhost:8000/api/v1";

// Mock data factories
export function createMockTag(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    name: "Test Tag",
    color: "#6366f1",
    area: "work",
    created_at: "2025-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockTask(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    title: "Test Task",
    description: "",
    notes: "",
    priority: "medium",
    area: "work",
    kanban_status: "todo",
    tags: [],
    scheduled_date: null,
    due_date: null,
    estimated_minutes: null,
    kanban_order: 0,
    is_completed: false,
    completed_at: null,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z",
    time_blocks: [],
    ...overrides,
  };
}

export function createMockTimeBlock(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    task: crypto.randomUUID(),
    date: "2025-01-15",
    start_time: "09:00:00",
    end_time: "10:00:00",
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockPomodoroSession(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    task: null,
    session_type: "focus",
    duration_minutes: 25,
    started_at: "2025-01-01T00:00:00Z",
    ended_at: null,
    completed: false,
    ...overrides,
  };
}

function paginated<T>(results: T[]) {
  return { count: results.length, next: null, previous: null, results };
}

// Default mock data
const mockTags = [createMockTag({ name: "Frontend" }), createMockTag({ name: "Backend" })];
const mockTasks = [
  createMockTask({ title: "Task 1", kanban_status: "todo" }),
  createMockTask({ title: "Task 2", kanban_status: "in_progress" }),
  createMockTask({ title: "Task 3", kanban_status: "done" }),
];

export const handlers = [
  // Tasks
  http.get(`${API_URL}/tasks/`, () =>
    HttpResponse.json(paginated(mockTasks))
  ),
  http.get(`${API_URL}/tasks/today/`, () =>
    HttpResponse.json(paginated(mockTasks))
  ),
  http.get(`${API_URL}/tasks/:id/`, ({ params }) => {
    const task = mockTasks.find((t) => t.id === params.id);
    return task ? HttpResponse.json(task) : new HttpResponse(null, { status: 404 });
  }),
  http.post(`${API_URL}/tasks/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockTask(body), { status: 201 });
  }),
  http.patch(`${API_URL}/tasks/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockTask({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/tasks/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),
  http.patch(`${API_URL}/tasks/reorder-bulk/`, () =>
    HttpResponse.json({ status: "ok" })
  ),

  // Tags
  http.get(`${API_URL}/tags/`, () =>
    HttpResponse.json(paginated(mockTags))
  ),
  http.post(`${API_URL}/tags/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockTag(body), { status: 201 });
  }),

  // Time Blocks
  http.get(`${API_URL}/timeblocks/`, () =>
    HttpResponse.json(paginated([createMockTimeBlock()]))
  ),
  http.post(`${API_URL}/timeblocks/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockTimeBlock(body), { status: 201 });
  }),
  http.patch(`${API_URL}/timeblocks/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockTimeBlock({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/timeblocks/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Pomodoro
  http.get(`${API_URL}/pomodoro/sessions/`, () =>
    HttpResponse.json(paginated([createMockPomodoroSession()]))
  ),
  http.post(`${API_URL}/pomodoro/sessions/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockPomodoroSession(body), { status: 201 });
  }),
  http.patch(`${API_URL}/pomodoro/sessions/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockPomodoroSession({ id: params.id, ...body }));
  }),
];

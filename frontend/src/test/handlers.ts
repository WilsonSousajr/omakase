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
    project: null,
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
    study_block: null,
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

export function createMockWorkspace(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    name: "Test Workspace",
    color: "#a3a3a3",
    project_count: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockSemester(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    name: "2026.1",
    institution: "UnB",
    start_date: "2026-03-01",
    end_date: "2026-07-15",
    status: "active",
    discipline_count: 0,
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockDiscipline(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    semester: crypto.randomUUID(),
    name: "Calculo 2",
    code: "MAT0026",
    professor: "Dr. Silva",
    color: "#a3a3a3",
    credits: 6,
    target_grade: null,
    status: "active",
    study_block_count: 0,
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockStudyBlock(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    discipline: crypto.randomUUID(),
    title: "Chapter 5 Exercises",
    block_type: "exercises",
    priority: "medium",
    status: "planned",
    notes: "",
    estimated_minutes: null,
    scheduled_date: null,
    due_date: null,
    is_completed: false,
    completed_at: null,
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockDailyStats(overrides = {}) {
  return {
    hours_focused_today: 0,
    blocks_completed_today: 0,
    blocks_total_today: 0,
    current_streak: 0,
    weekly_work_hours: 0,
    weekly_study_hours: 0,
    ...overrides,
  };
}

export function createMockProject(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    workspace: crypto.randomUUID(),
    name: "Test Project",
    description: "",
    color: "#a3a3a3",
    status: "active",
    due_date: null,
    task_count: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z",
    ...overrides,
  };
}

function paginated<T>(results: T[]) {
  return { count: results.length, next: null, previous: null, results };
}

export function createMockUser(overrides = {}) {
  return {
    id: 1,
    username: "testuser",
    email: "test@example.com",
    date_joined: "2025-01-01T00:00:00Z",
    ...overrides,
  };
}

export function createMockTokens(overrides = {}) {
  return {
    access: "mock-access-token",
    refresh: "mock-refresh-token",
    ...overrides,
  };
}

// Default mock data
const mockTags = [createMockTag({ name: "Frontend" }), createMockTag({ name: "Backend" })];
const mockTasks = [
  createMockTask({ title: "Task 1", kanban_status: "todo" }),
  createMockTask({ title: "Task 2", kanban_status: "in_progress" }),
  createMockTask({ title: "Task 3", kanban_status: "done" }),
];

export const handlers = [
  // Auth
  http.post(`${API_URL}/auth/register/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    if (body.username === "taken") {
      return HttpResponse.json(
        { username: ["A user with this username already exists."] },
        { status: 400 }
      );
    }
    return HttpResponse.json(createMockUser(body), { status: 201 });
  }),
  http.post(`${API_URL}/auth/token/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    if (body.password === "wrongpassword") {
      return HttpResponse.json(
        { detail: "No active account found with the given credentials" },
        { status: 401 }
      );
    }
    return HttpResponse.json(createMockTokens());
  }),
  http.post(`${API_URL}/auth/token/refresh/`, () =>
    HttpResponse.json({ access: "new-access-token" })
  ),
  http.get(`${API_URL}/auth/me/`, () =>
    HttpResponse.json(createMockUser())
  ),

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

  // Workspaces
  http.get(`${API_URL}/workspaces/`, () =>
    HttpResponse.json(paginated([createMockWorkspace({ name: "Work" }), createMockWorkspace({ name: "Personal" })]))
  ),
  http.post(`${API_URL}/workspaces/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockWorkspace(body), { status: 201 });
  }),
  http.patch(`${API_URL}/workspaces/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockWorkspace({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/workspaces/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Projects
  http.get(`${API_URL}/projects/`, () =>
    HttpResponse.json(paginated([createMockProject({ name: "Project Alpha" }), createMockProject({ name: "Project Beta" })]))
  ),
  http.post(`${API_URL}/projects/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockProject(body), { status: 201 });
  }),
  http.patch(`${API_URL}/projects/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockProject({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/projects/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Stats
  http.get(`${API_URL}/stats/daily/`, () =>
    HttpResponse.json(createMockDailyStats({
      hours_focused_today: 2.5,
      blocks_completed_today: 3,
      blocks_total_today: 5,
      current_streak: 7,
      weekly_work_hours: 12.0,
      weekly_study_hours: 4.5,
    }))
  ),

  // Semesters
  http.get(`${API_URL}/study/semesters/`, () =>
    HttpResponse.json(paginated([createMockSemester({ name: "2026.1" }), createMockSemester({ name: "2025.2" })]))
  ),
  http.post(`${API_URL}/study/semesters/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockSemester(body), { status: 201 });
  }),
  http.patch(`${API_URL}/study/semesters/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockSemester({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/study/semesters/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Disciplines
  http.get(`${API_URL}/study/disciplines/`, () =>
    HttpResponse.json(paginated([createMockDiscipline({ name: "Calculo 2" }), createMockDiscipline({ name: "Algebra Linear" })]))
  ),
  http.post(`${API_URL}/study/disciplines/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockDiscipline(body), { status: 201 });
  }),
  http.patch(`${API_URL}/study/disciplines/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockDiscipline({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/study/disciplines/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),

  // Study Blocks
  http.get(`${API_URL}/study/studyblocks/`, () =>
    HttpResponse.json(paginated([createMockStudyBlock({ title: "Chapter 5" }), createMockStudyBlock({ title: "Problem Set 3" })]))
  ),
  http.post(`${API_URL}/study/studyblocks/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockStudyBlock(body), { status: 201 });
  }),
  http.patch(`${API_URL}/study/studyblocks/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockStudyBlock({ id: params.id, ...body }));
  }),
  http.delete(`${API_URL}/study/studyblocks/:id/`, () =>
    new HttpResponse(null, { status: 204 })
  ),
];

# Daily Review & Shutdown — Design Document

> Last MVP feature. Closes the Plan → Focus → Review cycle.

---

## Data Model

### DailyReview (stats app)

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | PK |
| user | FK → User | |
| date | DateField | unique_together with user |
| productivity_rating | IntegerField(1-5) | Nullable, set in step 3 |
| win_of_the_day | TextField | Blank/nullable, set in step 4 |
| is_shutdown | BooleanField | Default False, set in step 6 |
| shutdown_at | DateTimeField | Nullable, stamped when shutdown |
| created_at | DateTimeField | auto_now_add |
| updated_at | DateTimeField | auto_now |

**Constraints:** `unique_together = ("user", "date")`, `productivity_rating` range 1-5 via validator.

**No changes to Task or StudyBlock models.** Rollover = PATCH `scheduled_date`. Backlog = clear `scheduled_date` to null. Skip (study blocks) = set `status="skipped"`.

---

## API

### Review Summary (read-only aggregation)

`GET /api/v1/stats/review/?date=YYYY-MM-DD`

Response:
```json
{
  "date": "2026-03-06",
  "hours_focused": 3.5,
  "blocks_completed": 4,
  "blocks_total": 6,
  "incomplete_tasks": [{ "id": "...", "title": "...", "estimated_minutes": 30 }],
  "incomplete_study_blocks": [{ "id": "...", "title": "...", "block_type": "theory" }],
  "completed_items": [
    { "id": "...", "title": "...", "type": "task", "estimated_minutes": 30, "actual_minutes": 45 }
  ],
  "daily_review": null
}
```

Custom `APIView` (same pattern as `DailyStatsView`). Aggregates TimeBlock, Task, StudyBlock, PomodoroSession data.

### DailyReview CRUD

- `GET /api/v1/stats/reviews/` — list user's reviews
- `POST /api/v1/stats/reviews/` — create review for a date
- `PATCH /api/v1/stats/reviews/<id>/` — update (add rating, win, shutdown)
- `GET /api/v1/stats/reviews/<id>/` — detail

Standard ViewSet, user-scoped via `get_queryset()` + `perform_create()`.

---

## Frontend Architecture

### Page: `/review`

Multi-step wizard with 6 steps. State managed via `useState<number>` for current step (0-5). Each step is a component in `components/review/`.

### Step 0 — Completion Summary (`ReviewSummary`)

- Header: "Today's Review" with formatted date
- Stats row: hours focused | blocks completed/total | completion %
- Two sections:
  - **Completed**: green checkmark, title, actual vs estimated time
  - **Incomplete**: orange indicator, title (addressed in next step)
- "Continue" button

### Step 1 — Rollover Decisions (`ReviewRollover`)

- Cards for each incomplete task and study block
- Per card, 4 action buttons:
  - **Tomorrow** (default, highlighted) — `scheduled_date = tomorrow`
  - **Pick date** — date picker → `scheduled_date = chosen`
  - **Backlog** — `scheduled_date = null`
  - **Skip/Cancel** — tasks: `scheduled_date = null`; study blocks: `status = "skipped"`
- Visual feedback: card dims with chosen action label after selection
- "Continue" enabled once all items have decisions
- If no incomplete items, auto-advance to step 2

### Step 2 — Productivity Score (`ReviewScore`)

- "How productive did you feel today?"
- 5 buttons: 1=Rough, 2=Below average, 3=Decent, 4=Good, 5=Crushing it
- Selected button gets white ring highlight
- "Continue" button

### Step 3 — Win of the Day (`ReviewWin`)

- "What was your biggest win today?"
- Textarea with placeholder
- Optional — "Skip" link available
- "Continue" button

### Step 4 — Tomorrow's Preview (`ReviewPreview`)

- Tomorrow's date header
- Lists scheduled time blocks, tasks, study blocks, and class occurrences
- Read-only, no editing
- "Finish" button

### Step 5 — Shutdown Confirmation (`ReviewShutdown`)

- Centered, spacious layout
- "Great work today. Time to rest."
- "Close" button → navigates to `/plan`

### Shutdown Nudge

When user navigates to `/plan` or `/focus` after `is_shutdown = true` for today:
- Dismissible toast: "You've shut down for the day. Rest well!"
- Shown once per session (tracked via `hasShownShutdownNudge` in uiStore)

### Sidebar

- Icon: `CheckSquare` from lucide-react
- Label: "Review"
- Position: after Focus (Plan → Focus → Review → Projects → Study)

---

## File Structure

```
backend/stats/
  models.py          ← add DailyReview model
  serializers.py     ← new file (DailyReviewSerializer, ReviewSummarySerializer)
  views.py           ← add ReviewSummaryView + DailyReviewViewSet
  urls.py            ← add routes
  admin.py           ← register DailyReview
  migrations/        ← new migration

frontend/src/
  app/(main)/review/page.tsx
  components/review/
    ReviewSummary.tsx
    ReviewRollover.tsx
    ReviewScore.tsx
    ReviewWin.tsx
    ReviewPreview.tsx
    ReviewShutdown.tsx
  hooks/useDailyReviews.ts
  types/dailyreview.ts
```

---

## Design Decisions

1. **DailyReview in stats app** — it's about daily aggregation, not task/study domain logic
2. **Wizard flow** — enforces the review as a deliberate ritual, not a skippable form
3. **Backlog = clear scheduled_date** — no new fields needed, task stays in system
4. **Review summary as custom APIView** — aggregates across models, same pattern as DailyStatsView
5. **Shutdown nudge via toast** — non-blocking, respectful, dismissible
6. **No model changes to Task/StudyBlock** — rollover is just changing scheduled_date via existing PATCH endpoints

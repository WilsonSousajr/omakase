# Daily Review & Shutdown Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Daily Review & Shutdown feature — a 6-step wizard that closes the daily Plan → Focus → Review cycle.

**Architecture:** New `DailyReview` model in `stats` app with `ReviewSummaryView` (read-only aggregation) and `DailyReviewViewSet` (CRUD). Frontend is a multi-step wizard at `/review` with 6 components. Rollover uses existing PATCH endpoints on tasks/study blocks. Shutdown nudge via toast on plan/focus pages.

**Tech Stack:** Django REST Framework (model, serializer, viewset, APIView), Next.js App Router page, React components with useState wizard, TanStack Query hooks, Zustand (uiStore for shutdown nudge flag), existing MSW test infrastructure.

**Design doc:** `docs/plans/2026-03-06-daily-review-design.md`

---

## Task 1: DailyReview Model + Migration

**Files:**
- Create: `backend/stats/models.py`
- Modify: `backend/conftest.py` (add DailyReviewFactory)

**Step 1: Create the model**

Create `backend/stats/models.py`:

```python
import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class DailyReview(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="daily_reviews",
    )
    date = models.DateField()
    productivity_rating = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    win_of_the_day = models.TextField(blank=True, default="")
    is_shutdown = models.BooleanField(default=False)
    shutdown_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user", "date")
        ordering = ["-date"]

    def __str__(self):
        return f"{self.user.username} — {self.date}"
```

**Step 2: Generate migration**

Run: `docker-compose exec backend python manage.py makemigrations stats`
Expected: Creates `stats/migrations/0001_initial.py`

**Step 3: Apply migration**

Run: `docker-compose exec backend python manage.py migrate stats`
Expected: `Applying stats.0001_initial... OK`

**Step 4: Add DailyReviewFactory to conftest.py**

Add import `from stats.models import DailyReview` at top of `backend/conftest.py`, then add after `ClassScheduleFactory`:

```python
class DailyReviewFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = DailyReview

    user = factory.LazyFunction(lambda: UserFactory())
    date = datetime.date.today()
    productivity_rating = None
    win_of_the_day = ""
    is_shutdown = False
```

Add fixture after `class_schedule` fixture:

```python
@pytest.fixture
def daily_review(db, user):
    return DailyReviewFactory(user=user)
```

**Step 5: Commit**

```
git add backend/stats/models.py backend/stats/migrations/ backend/conftest.py
git commit -m "feat: add DailyReview model with factory and migration"
```

---

## Task 2: DailyReview Serializer

**Files:**
- Create: `backend/stats/serializers.py`

**Step 1: Write the failing test**

Create `backend/stats/tests/test_serializers.py`:

```python
import datetime

import pytest

from conftest import DailyReviewFactory, UserFactory
from stats.serializers import DailyReviewSerializer


@pytest.mark.django_db
class TestDailyReviewSerializer:
    def test_serialize_daily_review(self):
        user = UserFactory()
        review = DailyReviewFactory(
            user=user,
            date=datetime.date(2026, 3, 6),
            productivity_rating=4,
            win_of_the_day="Finished the API refactor",
            is_shutdown=True,
        )
        data = DailyReviewSerializer(review).data
        assert str(data["id"]) == str(review.id)
        assert data["date"] == "2026-03-06"
        assert data["productivity_rating"] == 4
        assert data["win_of_the_day"] == "Finished the API refactor"
        assert data["is_shutdown"] is True

    def test_validate_productivity_rating_range(self):
        serializer = DailyReviewSerializer(
            data={"date": "2026-03-06", "productivity_rating": 6}
        )
        assert not serializer.is_valid()
        assert "productivity_rating" in serializer.errors

    def test_validate_productivity_rating_zero(self):
        serializer = DailyReviewSerializer(
            data={"date": "2026-03-06", "productivity_rating": 0}
        )
        assert not serializer.is_valid()
        assert "productivity_rating" in serializer.errors
```

**Step 2: Run test to verify it fails**

Run: `docker-compose exec backend pytest stats/tests/test_serializers.py -v`
Expected: FAIL — `ImportError: cannot import name 'DailyReviewSerializer'`

**Step 3: Write the serializer**

Create `backend/stats/serializers.py`:

```python
from rest_framework import serializers

from .models import DailyReview


class DailyReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyReview
        fields = [
            "id",
            "date",
            "productivity_rating",
            "win_of_the_day",
            "is_shutdown",
            "shutdown_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
```

**Step 4: Run test to verify it passes**

Run: `docker-compose exec backend pytest stats/tests/test_serializers.py -v`
Expected: 3 passed

**Step 5: Commit**

```
git add backend/stats/serializers.py backend/stats/tests/test_serializers.py
git commit -m "feat: add DailyReview serializer with validation tests"
```

---

## Task 3: DailyReviewViewSet (CRUD)

**Files:**
- Modify: `backend/stats/views.py`
- Modify: `backend/stats/urls.py`

**Step 1: Write the failing tests**

Create `backend/stats/tests/test_daily_review_views.py`:

```python
import datetime

import pytest
from django.utils import timezone
from rest_framework import status

from conftest import DailyReviewFactory


@pytest.mark.django_db
class TestDailyReviewViewSet:
    URL = "/api/v1/stats/reviews/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL)
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_create_daily_review(self, authenticated_client):
        resp = authenticated_client.post(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_201_CREATED
        assert resp.data["date"] == "2026-03-06"
        assert resp.data["is_shutdown"] is False
        assert resp.data["productivity_rating"] is None

    def test_create_duplicate_date_returns_400(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.post(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_update_review(self, authenticated_client, user):
        review = DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.patch(
            f"{self.URL}{review.id}/",
            {"productivity_rating": 4, "win_of_the_day": "Shipped the feature"},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["productivity_rating"] == 4
        assert resp.data["win_of_the_day"] == "Shipped the feature"

    def test_shutdown_sets_timestamp(self, authenticated_client, user):
        review = DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        resp = authenticated_client.patch(
            f"{self.URL}{review.id}/",
            {"is_shutdown": True},
        )
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["is_shutdown"] is True
        assert resp.data["shutdown_at"] is not None

    def test_list_scoped_to_user(self, authenticated_client, user):
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 5))
        DailyReviewFactory(user=user, date=datetime.date(2026, 3, 6))
        DailyReviewFactory()  # another user
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["count"] == 2
```

**Step 2: Run test to verify it fails**

Run: `docker-compose exec backend pytest stats/tests/test_daily_review_views.py -v`
Expected: FAIL — 404 (no URL route)

**Step 3: Add ViewSet to views.py**

Add to `backend/stats/views.py`:

```python
from django.utils import timezone as tz
from rest_framework import viewsets

from .models import DailyReview
from .serializers import DailyReviewSerializer
```

Then add the class after `DailyStatsView`:

```python
class DailyReviewViewSet(viewsets.ModelViewSet):
    serializer_class = DailyReviewSerializer

    def get_queryset(self):
        return DailyReview.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        # Auto-stamp shutdown_at when is_shutdown transitions to True
        instance = serializer.instance
        if serializer.validated_data.get("is_shutdown") and not instance.is_shutdown:
            serializer.save(shutdown_at=tz.now())
        else:
            serializer.save()
```

**Step 4: Add URL route**

Update `backend/stats/urls.py`:

```python
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DailyReviewViewSet, DailyStatsView

router = DefaultRouter()
router.register(r"reviews", DailyReviewViewSet, basename="daily-review")

urlpatterns = [
    path("daily/", DailyStatsView.as_view(), name="daily-stats"),
    path("", include(router.urls)),
]
```

**Step 5: Run test to verify it passes**

Run: `docker-compose exec backend pytest stats/tests/test_daily_review_views.py -v`
Expected: 6 passed

**Step 6: Run all backend tests to check for regressions**

Run: `docker-compose exec backend pytest -v --tb=short`
Expected: All pass

**Step 7: Commit**

```
git add backend/stats/views.py backend/stats/urls.py backend/stats/tests/test_daily_review_views.py
git commit -m "feat: add DailyReviewViewSet with CRUD and auto shutdown_at"
```

---

## Task 4: ReviewSummaryView (aggregation endpoint)

**Files:**
- Modify: `backend/stats/views.py`
- Modify: `backend/stats/urls.py`

**Step 1: Write the failing tests**

Add to `backend/stats/tests/test_views.py` (new test class):

```python
@pytest.mark.django_db
class TestReviewSummaryView:
    URL = "/api/v1/stats/review/"

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    def test_missing_date_returns_400(self, authenticated_client):
        resp = authenticated_client.get(self.URL)
        assert resp.status_code == status.HTTP_400_BAD_REQUEST

    def test_empty_day(self, authenticated_client):
        resp = authenticated_client.get(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["hours_focused"] == 0
        assert resp.data["blocks_completed"] == 0
        assert resp.data["blocks_total"] == 0
        assert resp.data["incomplete_tasks"] == []
        assert resp.data["incomplete_study_blocks"] == []
        assert resp.data["completed_items"] == []
        assert resp.data["daily_review"] is None

    def test_summary_with_data(self, authenticated_client, user):
        today = datetime.date(2026, 3, 6)
        # Completed task with time block
        completed_task = TaskFactory(
            user=user, title="Done task", is_completed=True,
            scheduled_date=today, estimated_minutes=30,
        )
        TimeBlockFactory(
            task=completed_task, date=today,
            start_time=datetime.time(9, 0), end_time=datetime.time(9, 45),
        )
        # Incomplete task
        TaskFactory(
            user=user, title="Pending task",
            scheduled_date=today, estimated_minutes=60,
        )
        resp = authenticated_client.get(self.URL, {"date": "2026-03-06"})
        assert resp.status_code == status.HTTP_200_OK
        assert resp.data["blocks_total"] == 1
        assert resp.data["blocks_completed"] == 1
        assert len(resp.data["incomplete_tasks"]) == 1
        assert resp.data["incomplete_tasks"][0]["title"] == "Pending task"
        assert len(resp.data["completed_items"]) == 1
        assert resp.data["completed_items"][0]["title"] == "Done task"
        assert resp.data["completed_items"][0]["actual_minutes"] == 45

    def test_includes_study_blocks(self, authenticated_client, user):
        from conftest import DisciplineFactory, StudyBlockFactory
        today = datetime.date(2026, 3, 6)
        disc = DisciplineFactory(semester__user=user)
        sb = StudyBlockFactory(
            discipline=disc, title="Incomplete SB",
            scheduled_date=today, status="planned",
        )
        resp = authenticated_client.get(self.URL, {"date": "2026-03-06"})
        assert len(resp.data["incomplete_study_blocks"]) == 1
        assert resp.data["incomplete_study_blocks"][0]["title"] == "Incomplete SB"

    def test_other_user_data_excluded(self, authenticated_client, user):
        today = datetime.date(2026, 3, 6)
        TaskFactory(title="Other user task", scheduled_date=today)  # different user
        resp = authenticated_client.get(self.URL, {"date": "2026-03-06"})
        assert len(resp.data["incomplete_tasks"]) == 0
```

**Step 2: Run test to verify it fails**

Run: `docker-compose exec backend pytest stats/tests/test_views.py::TestReviewSummaryView -v`
Expected: FAIL — 404

**Step 3: Write the ReviewSummaryView**

Add to `backend/stats/views.py`:

```python
from tasks.models import Task, TimeBlock
from study.models import StudyBlock
```

(Update the existing imports — `TimeBlock` is already imported, add `Task` and `StudyBlock`.)

Then add the class:

```python
class ReviewSummaryView(APIView):
    """Aggregate review data for a given date."""

    def get(self, request):
        date_str = request.query_params.get("date")
        if not date_str:
            return Response(
                {"detail": "date query parameter is required."},
                status=400,
            )

        try:
            review_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            return Response(
                {"detail": "Invalid date format. Use YYYY-MM-DD."},
                status=400,
            )

        user = request.user

        # Focused hours (Pomodoro)
        hours_focused = self._hours_focused(user, review_date)

        # Time blocks
        user_filter = Q(task__user=user) | Q(study_block__discipline__semester__user=user)
        blocks = TimeBlock.objects.filter(user_filter, date=review_date).select_related(
            "task", "study_block"
        )
        blocks_total = blocks.count()
        blocks_completed = blocks.filter(
            Q(task__is_completed=True) | Q(study_block__is_completed=True)
        ).count()

        # Incomplete tasks scheduled for this date
        incomplete_tasks = Task.objects.filter(
            user=user, scheduled_date=review_date, is_completed=False,
        ).values("id", "title", "priority", "area", "estimated_minutes")

        # Incomplete study blocks scheduled for this date
        incomplete_study_blocks = StudyBlock.objects.filter(
            discipline__semester__user=user,
            scheduled_date=review_date,
            is_completed=False,
        ).values("id", "title", "block_type", "priority", "estimated_minutes")

        # Completed items with actual time from time blocks
        completed_items = []
        for block in blocks:
            is_task = block.task is not None
            linked = block.task if is_task else block.study_block
            if not linked:
                continue
            if is_task and not linked.is_completed:
                continue
            if not is_task and not linked.is_completed:
                continue
            start = datetime.datetime.combine(block.date, block.start_time)
            end = datetime.datetime.combine(block.date, block.end_time)
            actual_min = int((end - start).total_seconds() / 60)
            completed_items.append({
                "id": str(linked.id),
                "title": linked.title,
                "type": "task" if is_task else "studyblock",
                "estimated_minutes": linked.estimated_minutes,
                "actual_minutes": actual_min,
            })

        # Existing DailyReview for this date
        daily_review = DailyReview.objects.filter(user=user, date=review_date).first()
        review_data = DailyReviewSerializer(daily_review).data if daily_review else None

        return Response({
            "date": review_date.isoformat(),
            "hours_focused": hours_focused,
            "blocks_completed": blocks_completed,
            "blocks_total": blocks_total,
            "incomplete_tasks": list(incomplete_tasks),
            "incomplete_study_blocks": list(incomplete_study_blocks),
            "completed_items": completed_items,
            "daily_review": review_data,
        })

    def _hours_focused(self, user, date):
        total = (
            PomodoroSession.objects.filter(
                user=user,
                session_type="focus",
                completed=True,
                started_at__date=date,
            )
            .aggregate(total=Coalesce(Sum("duration_minutes"), 0))["total"]
        )
        return round(total / 60, 1)
```

**Step 4: Add URL route**

Add to `backend/stats/urls.py` in `urlpatterns`:

```python
path("review/", ReviewSummaryView.as_view(), name="review-summary"),
```

Update the import to include `ReviewSummaryView`.

**Step 5: Run test to verify it passes**

Run: `docker-compose exec backend pytest stats/tests/test_views.py::TestReviewSummaryView -v`
Expected: 6 passed

**Step 6: Run all backend tests**

Run: `docker-compose exec backend pytest -v --tb=short`
Expected: All pass

**Step 7: Commit**

```
git add backend/stats/views.py backend/stats/urls.py backend/stats/tests/test_views.py
git commit -m "feat: add ReviewSummaryView aggregation endpoint"
```

---

## Task 5: Frontend Types + Hooks

**Files:**
- Create: `frontend/src/types/dailyreview.ts`
- Create: `frontend/src/hooks/useDailyReviews.ts`
- Modify: `frontend/src/test/handlers.ts` (add MSW handlers)

**Step 1: Create the type**

Create `frontend/src/types/dailyreview.ts`:

```typescript
export interface DailyReview {
  id: string;
  date: string;
  productivity_rating: number | null;
  win_of_the_day: string;
  is_shutdown: boolean;
  shutdown_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ReviewSummary {
  date: string;
  hours_focused: number;
  blocks_completed: number;
  blocks_total: number;
  incomplete_tasks: ReviewIncompleteTask[];
  incomplete_study_blocks: ReviewIncompleteStudyBlock[];
  completed_items: ReviewCompletedItem[];
  daily_review: DailyReview | null;
}

export interface ReviewIncompleteTask {
  id: string;
  title: string;
  priority: string;
  area: string;
  estimated_minutes: number | null;
}

export interface ReviewIncompleteStudyBlock {
  id: string;
  title: string;
  block_type: string;
  priority: string;
  estimated_minutes: number | null;
}

export interface ReviewCompletedItem {
  id: string;
  title: string;
  type: "task" | "studyblock";
  estimated_minutes: number | null;
  actual_minutes: number;
}
```

**Step 2: Create the hooks**

Create `frontend/src/hooks/useDailyReviews.ts`:

```typescript
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { DailyReview, ReviewSummary } from "@/types/dailyreview";

interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export function useReviewSummary(date: string) {
  return useQuery({
    queryKey: ["review-summary", date],
    queryFn: async () => {
      const { data } = await api.get<ReviewSummary>("/stats/review/", {
        params: { date },
      });
      return data;
    },
    enabled: !!date,
  });
}

export function useDailyReview(date: string) {
  return useQuery({
    queryKey: ["daily-reviews", date],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<DailyReview>>(
        "/stats/reviews/",
        { params: { date } }
      );
      return data.results[0] ?? null;
    },
    enabled: !!date,
  });
}

export function useCreateDailyReview() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { date: string }) => {
      const { data } = await api.post<DailyReview>("/stats/reviews/", payload);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["daily-reviews"] });
      queryClient.invalidateQueries({ queryKey: ["review-summary"] });
    },
  });
}

export function useUpdateDailyReview() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({
      id,
      ...updates
    }: { id: string } & Partial<
      Pick<DailyReview, "productivity_rating" | "win_of_the_day" | "is_shutdown">
    >) => {
      const { data } = await api.patch<DailyReview>(
        `/stats/reviews/${id}/`,
        updates
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["daily-reviews"] });
      queryClient.invalidateQueries({ queryKey: ["review-summary"] });
    },
  });
}
```

**Step 3: Add MSW handlers**

Add to `frontend/src/test/handlers.ts`:

1. Add mock factory:

```typescript
export function createMockDailyReview(overrides = {}) {
  return {
    id: crypto.randomUUID(),
    date: "2026-03-06",
    productivity_rating: null,
    win_of_the_day: "",
    is_shutdown: false,
    shutdown_at: null,
    created_at: "2026-03-06T22:00:00Z",
    updated_at: "2026-03-06T22:00:00Z",
    ...overrides,
  };
}

export function createMockReviewSummary(overrides = {}) {
  return {
    date: "2026-03-06",
    hours_focused: 0,
    blocks_completed: 0,
    blocks_total: 0,
    incomplete_tasks: [],
    incomplete_study_blocks: [],
    completed_items: [],
    daily_review: null,
    ...overrides,
  };
}
```

2. Add handlers to the `handlers` array:

```typescript
  // Daily Reviews
  http.get(`${API_URL}/stats/review/`, () =>
    HttpResponse.json(createMockReviewSummary())
  ),
  http.get(`${API_URL}/stats/reviews/`, () =>
    HttpResponse.json(paginated([]))
  ),
  http.post(`${API_URL}/stats/reviews/`, async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockDailyReview(body), { status: 201 });
  }),
  http.patch(`${API_URL}/stats/reviews/:id/`, async ({ request, params }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(createMockDailyReview({ id: params.id, ...body }));
  }),
```

**Step 4: Write hook tests**

Create `frontend/src/hooks/__tests__/useDailyReviews.test.tsx`:

```tsx
import { renderHook, waitFor } from "@testing-library/react";
import { createWrapper } from "@/test/utils";
import { useReviewSummary, useCreateDailyReview } from "@/hooks/useDailyReviews";

describe("useReviewSummary", () => {
  it("fetches review summary for a date", async () => {
    const { result } = renderHook(() => useReviewSummary("2026-03-06"), {
      wrapper: createWrapper(),
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.date).toBe("2026-03-06");
    expect(result.current.data?.incomplete_tasks).toEqual([]);
  });
});

describe("useCreateDailyReview", () => {
  it("creates a daily review", async () => {
    const { result } = renderHook(() => useCreateDailyReview(), {
      wrapper: createWrapper(),
    });
    result.current.mutate({ date: "2026-03-06" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.date).toBe("2026-03-06");
  });
});
```

Check `frontend/src/test/utils.tsx` for `createWrapper` — if it doesn't export that, use `renderWithProviders` pattern. The hook tests need a `QueryClientProvider` wrapper.

**Step 5: Run tests**

Run: `cd frontend && npx pnpm test src/hooks/__tests__/useDailyReviews.test.tsx`
Expected: 2 passed

**Step 6: Commit**

```
git add frontend/src/types/dailyreview.ts frontend/src/hooks/useDailyReviews.ts frontend/src/test/handlers.ts frontend/src/hooks/__tests__/useDailyReviews.test.tsx
git commit -m "feat: add DailyReview types, hooks, MSW handlers, and tests"
```

---

## Task 6: Sidebar + Review Page Shell + uiStore Shutdown Flag

**Files:**
- Modify: `frontend/src/components/Sidebar.tsx` (add Review nav item)
- Create: `frontend/src/app/(main)/review/page.tsx` (wizard shell)
- Modify: `frontend/src/stores/uiStore.ts` (add `hasShownShutdownNudge`)

**Step 1: Add Review to sidebar**

In `frontend/src/components/Sidebar.tsx`, add `CheckSquare` to the lucide-react import, then add after Focus in `NAV_ITEMS`:

```typescript
{ href: "/review", label: "Review", icon: CheckSquare },
```

**Step 2: Add shutdown nudge flag to uiStore**

In `frontend/src/stores/uiStore.ts`, add to the interface:

```typescript
hasShownShutdownNudge: boolean;
setHasShownShutdownNudge: (value: boolean) => void;
```

And in the `create` body:

```typescript
hasShownShutdownNudge: false,
setHasShownShutdownNudge: (value) => set({ hasShownShutdownNudge: value }),
```

**Step 3: Create the review page wizard shell**

Create `frontend/src/app/(main)/review/page.tsx`:

```tsx
"use client";

import { useState } from "react";
import { format } from "date-fns";
import { useReviewSummary, useCreateDailyReview, useUpdateDailyReview } from "@/hooks/useDailyReviews";
import ReviewSummary from "@/components/review/ReviewSummary";
import ReviewRollover from "@/components/review/ReviewRollover";
import ReviewScore from "@/components/review/ReviewScore";
import ReviewWin from "@/components/review/ReviewWin";
import ReviewPreview from "@/components/review/ReviewPreview";
import ReviewShutdown from "@/components/review/ReviewShutdown";
import type { DailyReview } from "@/types/dailyreview";

const STEPS = ["Summary", "Rollover", "Score", "Win", "Preview", "Shutdown"];

export default function ReviewPage() {
  const today = format(new Date(), "yyyy-MM-dd");
  const { data: summary, isLoading } = useReviewSummary(today);
  const createReview = useCreateDailyReview();
  const updateReview = useUpdateDailyReview();

  const [step, setStep] = useState(0);
  const [reviewId, setReviewId] = useState<string | null>(
    summary?.daily_review?.id ?? null
  );
  const [rating, setRating] = useState<number | null>(null);
  const [win, setWin] = useState("");

  const ensureReview = async (): Promise<string> => {
    if (reviewId) return reviewId;
    const created = await createReview.mutateAsync({ date: today });
    setReviewId(created.id);
    return created.id;
  };

  const handleNext = () => setStep((s) => Math.min(s + 1, STEPS.length - 1));

  const handleSaveRating = async () => {
    const id = await ensureReview();
    await updateReview.mutateAsync({ id, productivity_rating: rating });
    handleNext();
  };

  const handleSaveWin = async () => {
    const id = await ensureReview();
    if (win.trim()) {
      await updateReview.mutateAsync({ id, win_of_the_day: win.trim() });
    }
    handleNext();
  };

  const handleShutdown = async () => {
    const id = await ensureReview();
    await updateReview.mutateAsync({ id, is_shutdown: true });
  };

  if (isLoading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-[var(--color-text-faint)] border-t-[var(--color-text-primary)]" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col">
      {/* Step indicator */}
      <div className="flex items-center justify-center gap-1.5 border-b border-[var(--color-border)] px-6 py-3">
        {STEPS.map((label, i) => (
          <div key={label} className="flex items-center gap-1.5">
            <div
              className={`h-1.5 w-1.5 rounded-full ${
                i <= step ? "bg-[var(--color-text-primary)]" : "bg-[var(--color-text-faint)]"
              }`}
            />
            {i < STEPS.length - 1 && (
              <div
                className={`h-px w-6 ${
                  i < step ? "bg-[var(--color-text-primary)]" : "bg-[var(--color-text-faint)]"
                }`}
              />
            )}
          </div>
        ))}
      </div>

      {/* Step content */}
      <div className="flex flex-1 items-center justify-center overflow-auto p-8">
        <div className="w-full max-w-2xl">
          {step === 0 && summary && (
            <ReviewSummary summary={summary} onNext={handleNext} />
          )}
          {step === 1 && summary && (
            <ReviewRollover summary={summary} onNext={handleNext} />
          )}
          {step === 2 && (
            <ReviewScore rating={rating} onRate={setRating} onNext={handleSaveRating} />
          )}
          {step === 3 && (
            <ReviewWin win={win} onChangeWin={setWin} onNext={handleSaveWin} />
          )}
          {step === 4 && (
            <ReviewPreview onNext={handleNext} />
          )}
          {step === 5 && (
            <ReviewShutdown onShutdown={handleShutdown} />
          )}
        </div>
      </div>
    </div>
  );
}
```

**Step 4: Commit**

```
git add frontend/src/components/Sidebar.tsx frontend/src/stores/uiStore.ts frontend/src/app/\(main\)/review/page.tsx
git commit -m "feat: add review page shell, sidebar nav item, and shutdown nudge flag"
```

---

## Task 7: ReviewSummary Component (Step 0)

**Files:**
- Create: `frontend/src/components/review/ReviewSummary.tsx`

**Step 1: Create the component**

```tsx
"use client";

import { Check, Circle } from "lucide-react";
import type { ReviewSummary as ReviewSummaryType } from "@/types/dailyreview";

interface Props {
  summary: ReviewSummaryType;
  onNext: () => void;
}

export default function ReviewSummary({ summary, onNext }: Props) {
  const completionPct =
    summary.blocks_total > 0
      ? Math.round((summary.blocks_completed / summary.blocks_total) * 100)
      : 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          Today&apos;s Review
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">{summary.date}</p>
      </div>

      {/* Stats row */}
      <div className="flex gap-4">
        {[
          { label: "Hours focused", value: `${summary.hours_focused}h` },
          { label: "Blocks", value: `${summary.blocks_completed}/${summary.blocks_total}` },
          { label: "Completion", value: `${completionPct}%` },
        ].map((stat) => (
          <div
            key={stat.label}
            className="flex-1 rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-center"
          >
            <div className="text-xl font-semibold text-[var(--color-text-primary)]">
              {stat.value}
            </div>
            <div className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {stat.label}
            </div>
          </div>
        ))}
      </div>

      {/* Completed items */}
      {summary.completed_items.length > 0 && (
        <div>
          <h3 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Completed
          </h3>
          <div className="space-y-1.5">
            {summary.completed_items.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
              >
                <Check className="h-3.5 w-3.5 shrink-0 text-green-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {item.title}
                </span>
                {item.estimated_minutes && (
                  <span className="text-xs text-[var(--color-text-faint)]">
                    {item.actual_minutes}m / {item.estimated_minutes}m est.
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Incomplete items */}
      {(summary.incomplete_tasks.length > 0 ||
        summary.incomplete_study_blocks.length > 0) && (
        <div>
          <h3 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Incomplete
          </h3>
          <div className="space-y-1.5">
            {summary.incomplete_tasks.map((task) => (
              <div
                key={task.id}
                className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-2"
              >
                <Circle className="h-3.5 w-3.5 shrink-0 text-amber-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {task.title}
                </span>
              </div>
            ))}
            {summary.incomplete_study_blocks.map((sb) => (
              <div
                key={sb.id}
                className="flex items-center gap-2 rounded-xl border border-amber-500/20 bg-[var(--color-surface)] px-3 py-2"
              >
                <Circle className="h-3.5 w-3.5 shrink-0 text-amber-500" />
                <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                  {sb.title}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="flex justify-end pt-2">
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          Continue
        </button>
      </div>
    </div>
  );
}
```

**Step 2: Commit**

```
git add frontend/src/components/review/ReviewSummary.tsx
git commit -m "feat: add ReviewSummary component (step 0)"
```

---

## Task 8: ReviewRollover Component (Step 1)

**Files:**
- Create: `frontend/src/components/review/ReviewRollover.tsx`

**Step 1: Create the component**

```tsx
"use client";

import { useState } from "react";
import { format, addDays } from "date-fns";
import { CalendarArrowUp, CalendarDays, Inbox, XCircle } from "lucide-react";
import { useUpdateTask } from "@/hooks/useTasks";
import { useUpdateStudyBlock } from "@/hooks/useStudyBlocks";
import type { ReviewSummary } from "@/types/dailyreview";

type RolloverAction = "tomorrow" | "pick" | "backlog" | "skip";

interface ItemDecision {
  action: RolloverAction;
  date?: string;
}

interface Props {
  summary: ReviewSummary;
  onNext: () => void;
}

export default function ReviewRollover({ summary, onNext }: Props) {
  const updateTask = useUpdateTask();
  const updateStudyBlock = useUpdateStudyBlock();
  const tomorrow = format(addDays(new Date(), 1), "yyyy-MM-dd");

  const allItems = [
    ...summary.incomplete_tasks.map((t) => ({ ...t, itemType: "task" as const })),
    ...summary.incomplete_study_blocks.map((sb) => ({ ...sb, itemType: "studyblock" as const })),
  ];

  const [decisions, setDecisions] = useState<Record<string, ItemDecision>>({});

  if (allItems.length === 0) {
    // No incomplete items — auto-advance
    return (
      <div className="space-y-6 text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          All done!
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          Everything scheduled for today was completed.
        </p>
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          Continue
        </button>
      </div>
    );
  }

  const allDecided = allItems.every((item) => decisions[item.id]);

  const setDecision = (id: string, decision: ItemDecision) => {
    setDecisions((prev) => ({ ...prev, [id]: decision }));
  };

  const handleApply = async () => {
    for (const item of allItems) {
      const decision = decisions[item.id];
      if (!decision) continue;

      if (item.itemType === "task") {
        if (decision.action === "tomorrow") {
          await updateTask.mutateAsync({ id: item.id, scheduled_date: tomorrow });
        } else if (decision.action === "pick" && decision.date) {
          await updateTask.mutateAsync({ id: item.id, scheduled_date: decision.date });
        } else if (decision.action === "backlog" || decision.action === "skip") {
          await updateTask.mutateAsync({ id: item.id, scheduled_date: null });
        }
      } else {
        if (decision.action === "tomorrow") {
          await updateStudyBlock.mutateAsync({ id: item.id, scheduled_date: tomorrow });
        } else if (decision.action === "pick" && decision.date) {
          await updateStudyBlock.mutateAsync({ id: item.id, scheduled_date: decision.date });
        } else if (decision.action === "backlog") {
          await updateStudyBlock.mutateAsync({ id: item.id, scheduled_date: null });
        } else if (decision.action === "skip") {
          await updateStudyBlock.mutateAsync({ id: item.id, status: "skipped" });
        }
      }
    }
    onNext();
  };

  const actionButtons: { action: RolloverAction; icon: typeof CalendarArrowUp; label: string }[] = [
    { action: "tomorrow", icon: CalendarArrowUp, label: "Tomorrow" },
    { action: "pick", icon: CalendarDays, label: "Pick date" },
    { action: "backlog", icon: Inbox, label: "Backlog" },
    { action: "skip", icon: XCircle, label: "Skip" },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          Rollover Decisions
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          What should happen with each incomplete item?
        </p>
      </div>

      <div className="space-y-3">
        {allItems.map((item) => {
          const decision = decisions[item.id];
          return (
            <div
              key={item.id}
              className={`rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition-opacity ${
                decision ? "opacity-60" : ""
              }`}
            >
              <div className="mb-3 flex items-center justify-between">
                <span className="text-sm font-medium text-[var(--color-text-primary)]">
                  {item.title}
                </span>
                {decision && (
                  <span className="rounded-lg bg-white/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {decision.action === "pick" ? decision.date : decision.action}
                  </span>
                )}
              </div>
              <div className="flex gap-2">
                {actionButtons.map(({ action, icon: Icon, label }) => (
                  <button
                    key={action}
                    onClick={() => {
                      if (action === "pick") {
                        // For MVP, prompt with a simple input
                        const picked = prompt("Enter date (YYYY-MM-DD):");
                        if (picked) setDecision(item.id, { action, date: picked });
                      } else {
                        setDecision(item.id, { action });
                      }
                    }}
                    className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs transition-colors ${
                      decision?.action === action
                        ? "bg-white/15 text-[var(--color-text-primary)]"
                        : "text-[var(--color-text-secondary)] hover:bg-white/5 hover:text-[var(--color-text-primary)]"
                    }`}
                  >
                    <Icon className="h-3.5 w-3.5" />
                    {label}
                  </button>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      <div className="flex justify-end pt-2">
        <button
          onClick={handleApply}
          disabled={!allDecided}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          Apply &amp; Continue
        </button>
      </div>
    </div>
  );
}
```

**Step 2: Commit**

```
git add frontend/src/components/review/ReviewRollover.tsx
git commit -m "feat: add ReviewRollover component (step 1)"
```

---

## Task 9: ReviewScore + ReviewWin + ReviewPreview + ReviewShutdown (Steps 2-5)

**Files:**
- Create: `frontend/src/components/review/ReviewScore.tsx`
- Create: `frontend/src/components/review/ReviewWin.tsx`
- Create: `frontend/src/components/review/ReviewPreview.tsx`
- Create: `frontend/src/components/review/ReviewShutdown.tsx`

**Step 1: Create ReviewScore**

```tsx
"use client";

interface Props {
  rating: number | null;
  onRate: (rating: number) => void;
  onNext: () => void;
}

const LABELS = ["Rough", "Below avg", "Decent", "Good", "Crushing it"];

export default function ReviewScore({ rating, onRate, onNext }: Props) {
  return (
    <div className="space-y-8 text-center">
      <div>
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          How productive did you feel today?
        </h2>
      </div>

      <div className="flex justify-center gap-3">
        {LABELS.map((label, i) => {
          const value = i + 1;
          const isSelected = rating === value;
          return (
            <button
              key={value}
              onClick={() => onRate(value)}
              className={`flex flex-col items-center gap-1.5 rounded-2xl border px-4 py-3 transition-all ${
                isSelected
                  ? "border-[var(--color-text-primary)] bg-white/10 ring-1 ring-white/20"
                  : "border-[var(--color-border)] hover:bg-white/5"
              }`}
            >
              <span className="text-xl font-semibold text-[var(--color-text-primary)]">
                {value}
              </span>
              <span className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {label}
              </span>
            </button>
          );
        })}
      </div>

      <div className="flex justify-end">
        <button
          onClick={onNext}
          disabled={rating === null}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
        >
          Continue
        </button>
      </div>
    </div>
  );
}
```

**Step 2: Create ReviewWin**

```tsx
"use client";

interface Props {
  win: string;
  onChangeWin: (value: string) => void;
  onNext: () => void;
}

export default function ReviewWin({ win, onChangeWin, onNext }: Props) {
  return (
    <div className="space-y-6">
      <div className="text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          What was your biggest win today?
        </h2>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          Optional — but reflecting on wins builds momentum.
        </p>
      </div>

      <textarea
        value={win}
        onChange={(e) => onChangeWin(e.target.value)}
        placeholder="e.g., Finally finished the API refactor..."
        rows={3}
        className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
      />

      <div className="flex items-center justify-between">
        <button
          onClick={onNext}
          className="text-xs text-[var(--color-text-faint)] hover:text-[var(--color-text-secondary)]"
        >
          Skip
        </button>
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          Continue
        </button>
      </div>
    </div>
  );
}
```

**Step 3: Create ReviewPreview**

```tsx
"use client";

import { format, addDays } from "date-fns";
import { useTimeBlocks } from "@/hooks/useTimeBlocks";
import { useTasks } from "@/hooks/useTasks";
import { useStudyBlocks } from "@/hooks/useStudyBlocks";
import { useClassOccurrences } from "@/hooks/useClassOccurrences";

interface Props {
  onNext: () => void;
}

export default function ReviewPreview({ onNext }: Props) {
  const tomorrow = format(addDays(new Date(), 1), "yyyy-MM-dd");
  const { data: timeBlocks = [] } = useTimeBlocks(tomorrow, tomorrow);
  const { data: tasks = [] } = useTasks({ scheduled_date: tomorrow });
  const { data: studyBlocks = [] } = useStudyBlocks({ scheduled_date: tomorrow });
  const { data: classOccurrences = [] } = useClassOccurrences(tomorrow, tomorrow);

  const hasContent =
    timeBlocks.length > 0 ||
    tasks.length > 0 ||
    studyBlocks.length > 0 ||
    classOccurrences.length > 0;

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
          Tomorrow&apos;s Preview
        </h2>
        <p className="text-sm text-[var(--color-text-muted)]">
          {format(addDays(new Date(), 1), "EEEE, MMMM d")}
        </p>
      </div>

      {!hasContent ? (
        <p className="text-center text-sm text-[var(--color-text-muted)]">
          Nothing scheduled yet. You&apos;ll plan in the morning.
        </p>
      ) : (
        <div className="space-y-2">
          {classOccurrences.map((occ) => (
            <div
              key={occ.id}
              className="flex items-center gap-2 rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <div
                className="h-2 w-2 rounded-full"
                style={{ backgroundColor: occ.discipline_color }}
              />
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {occ.discipline_name} — {occ.class_type}
              </span>
              <span className="text-xs text-[var(--color-text-faint)]">
                {occ.start_time.slice(0, 5)} – {occ.end_time.slice(0, 5)}
              </span>
            </div>
          ))}
          {tasks.map((task) => (
            <div
              key={task.id}
              className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {task.title}
              </span>
            </div>
          ))}
          {studyBlocks.map((sb) => (
            <div
              key={sb.id}
              className="flex items-center gap-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-2"
            >
              <span className="flex-1 text-sm text-[var(--color-text-primary)]">
                {sb.title}
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="flex justify-end pt-2">
        <button
          onClick={onNext}
          className="rounded-xl bg-[var(--color-button-primary)] px-6 py-2 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          Finish
        </button>
      </div>
    </div>
  );
}
```

**Step 4: Create ReviewShutdown**

```tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Moon } from "lucide-react";
import { useUIStore } from "@/stores/uiStore";

interface Props {
  onShutdown: () => Promise<void>;
}

export default function ReviewShutdown({ onShutdown }: Props) {
  const router = useRouter();
  const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);
  const [isShuttingDown, setIsShuttingDown] = useState(false);
  const [isDone, setIsDone] = useState(false);

  const handleShutdown = async () => {
    setIsShuttingDown(true);
    await onShutdown();
    setIsShuttingDown(false);
    setIsDone(true);
    setHasShownShutdownNudge(false); // Reset so nudge can show on plan/focus
  };

  return (
    <div className="flex flex-col items-center justify-center space-y-6 py-12 text-center">
      <Moon className="h-10 w-10 text-[var(--color-text-faint)]" />

      {!isDone ? (
        <>
          <div>
            <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
              Ready to shut down?
            </h2>
            <p className="mt-2 text-sm text-[var(--color-text-muted)]">
              You&apos;ve done great work today. Time to rest and recharge.
            </p>
          </div>
          <button
            onClick={handleShutdown}
            disabled={isShuttingDown}
            className="rounded-xl bg-[var(--color-button-primary)] px-8 py-2.5 text-sm font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
          >
            {isShuttingDown ? "Shutting down..." : "Shut Down"}
          </button>
        </>
      ) : (
        <>
          <div>
            <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
              Great work today. Time to rest.
            </h2>
          </div>
          <button
            onClick={() => router.push("/plan")}
            className="rounded-xl px-6 py-2 text-xs text-[var(--color-text-secondary)] hover:bg-white/5 hover:text-[var(--color-text-primary)]"
          >
            Close
          </button>
        </>
      )}
    </div>
  );
}
```

**Step 5: Commit**

```
git add frontend/src/components/review/ReviewScore.tsx frontend/src/components/review/ReviewWin.tsx frontend/src/components/review/ReviewPreview.tsx frontend/src/components/review/ReviewShutdown.tsx
git commit -m "feat: add ReviewScore, ReviewWin, ReviewPreview, ReviewShutdown components"
```

---

## Task 10: Shutdown Nudge on Plan/Focus Pages

**Files:**
- Modify: `frontend/src/app/(main)/plan/page.tsx`
- Modify: `frontend/src/app/(main)/focus/page.tsx`

**Step 1: Add shutdown nudge hook**

The nudge logic is the same for both pages. Add to each page:

```tsx
import { useEffect } from "react";
import { format } from "date-fns";
import { useDailyReview } from "@/hooks/useDailyReviews";
import { useUIStore } from "@/stores/uiStore";
```

Then inside the component function, before the return:

```tsx
const today = format(new Date(), "yyyy-MM-dd");
const { data: todayReview } = useDailyReview(today);
const hasShownShutdownNudge = useUIStore((s) => s.hasShownShutdownNudge);
const setHasShownShutdownNudge = useUIStore((s) => s.setHasShownShutdownNudge);

useEffect(() => {
  if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
    // Import emitToast from Toast or use a lightweight approach
    setHasShownShutdownNudge(true);
  }
}, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);
```

For the toast, we need the `emitToast` function from `Toast.tsx` to be importable. The current `emitToast` is module-private. Either:
- (a) Export `emitToast` from `Toast.tsx`, or
- (b) Use a simple banner component instead

**Recommended approach (a):** Export `emitToast` from Toast.tsx and call it in the useEffect:

In `frontend/src/components/Toast.tsx`, change `function emitToast` to `export function emitToast`.

Then in plan/focus pages:

```tsx
import { emitToast } from "@/components/Toast";

useEffect(() => {
  if (todayReview?.is_shutdown && !hasShownShutdownNudge) {
    emitToast("You've shut down for the day. Rest well!");
    setHasShownShutdownNudge(true);
  }
}, [todayReview, hasShownShutdownNudge, setHasShownShutdownNudge]);
```

**Step 2: Commit**

```
git add frontend/src/components/Toast.tsx frontend/src/app/\(main\)/plan/page.tsx frontend/src/app/\(main\)/focus/page.tsx
git commit -m "feat: add shutdown nudge toast on plan and focus pages"
```

---

## Task 11: Frontend Tests

**Files:**
- Create: `frontend/src/components/review/__tests__/ReviewSummary.test.tsx`
- Create: `frontend/src/components/review/__tests__/ReviewScore.test.tsx`
- Create: `frontend/src/components/review/__tests__/ReviewShutdown.test.tsx`

**Step 1: Test ReviewSummary**

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ReviewSummary from "../ReviewSummary";
import type { ReviewSummary as ReviewSummaryType } from "@/types/dailyreview";

const baseSummary: ReviewSummaryType = {
  date: "2026-03-06",
  hours_focused: 2.5,
  blocks_completed: 3,
  blocks_total: 5,
  incomplete_tasks: [
    { id: "1", title: "Pending task", priority: "medium", area: "work", estimated_minutes: 30 },
  ],
  incomplete_study_blocks: [],
  completed_items: [
    { id: "2", title: "Done task", type: "task", estimated_minutes: 30, actual_minutes: 45 },
  ],
  daily_review: null,
};

describe("ReviewSummary", () => {
  it("renders stats", () => {
    render(<ReviewSummary summary={baseSummary} onNext={vi.fn()} />);
    expect(screen.getByText("2.5h")).toBeInTheDocument();
    expect(screen.getByText("3/5")).toBeInTheDocument();
    expect(screen.getByText("60%")).toBeInTheDocument();
  });

  it("renders completed and incomplete items", () => {
    render(<ReviewSummary summary={baseSummary} onNext={vi.fn()} />);
    expect(screen.getByText("Done task")).toBeInTheDocument();
    expect(screen.getByText("Pending task")).toBeInTheDocument();
  });

  it("calls onNext when Continue clicked", async () => {
    const onNext = vi.fn();
    render(<ReviewSummary summary={baseSummary} onNext={onNext} />);
    await userEvent.click(screen.getByText("Continue"));
    expect(onNext).toHaveBeenCalledOnce();
  });
});
```

**Step 2: Test ReviewScore**

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ReviewScore from "../ReviewScore";

describe("ReviewScore", () => {
  it("renders 5 rating buttons", () => {
    render(<ReviewScore rating={null} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("1")).toBeInTheDocument();
    expect(screen.getByText("5")).toBeInTheDocument();
  });

  it("calls onRate when button clicked", async () => {
    const onRate = vi.fn();
    render(<ReviewScore rating={null} onRate={onRate} onNext={vi.fn()} />);
    await userEvent.click(screen.getByText("4"));
    expect(onRate).toHaveBeenCalledWith(4);
  });

  it("disables Continue when no rating", () => {
    render(<ReviewScore rating={null} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("Continue")).toBeDisabled();
  });

  it("enables Continue when rated", () => {
    render(<ReviewScore rating={3} onRate={vi.fn()} onNext={vi.fn()} />);
    expect(screen.getByText("Continue")).not.toBeDisabled();
  });
});
```

**Step 3: Test ReviewShutdown**

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
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
    expect(screen.getByText("Great work today. Time to rest.")).toBeInTheDocument();
  });
});
```

**Step 4: Run tests**

Run: `cd frontend && npx pnpm test src/components/review/`
Expected: All pass

**Step 5: Commit**

```
git add frontend/src/components/review/__tests__/
git commit -m "test: add ReviewSummary, ReviewScore, ReviewShutdown tests"
```

---

## Task 12: Update CLAUDE.md + Design System Docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/design-system.md`
- Delete: `docs/plans/2026-03-06-daily-review-design.md`
- Delete: `docs/plans/2026-03-06-daily-review.md`

**Step 1: Add to CLAUDE.md**

Add to API Endpoints section:
```
- `stats/review/` — GET review summary for a date (date param required)
- `stats/reviews/` — CRUD DailyReview (user-scoped)
```

Add to Key Patterns section:
```
- DailyReview in stats app — stores productivity_rating (1-5), win_of_the_day, is_shutdown + shutdown_at
- DailyReview.perform_update auto-stamps shutdown_at when is_shutdown transitions to True
- Review page is a 6-step wizard: Summary → Rollover → Score → Win → Preview → Shutdown
- Rollover = PATCH scheduled_date on tasks/study blocks (tomorrow, pick date, or null for backlog)
- Study block "skip" action sets status="skipped" (not just clearing scheduled_date)
- Shutdown nudge: toast on plan/focus pages when today's review has is_shutdown=true, shown once per session via uiStore flag
- ReviewSummaryView aggregates TimeBlock, Task, StudyBlock, PomodoroSession data for any given date
- Frontend: useReviewSummary(date) hook for the aggregation endpoint, useDailyReview(date) for CRUD
- Frontend: emitToast exported from Toast.tsx for programmatic toast messages
```

Add to Project Structure:
```
components/review/     # ReviewSummary, ReviewRollover, ReviewScore, ReviewWin, ReviewPreview, ReviewShutdown
hooks/useDailyReviews  # useReviewSummary, useDailyReview, useCreateDailyReview, useUpdateDailyReview
types/dailyreview      # DailyReview, ReviewSummary, ReviewIncompleteTask, etc.
```

**Step 2: Delete plan files**

```bash
rm docs/plans/2026-03-06-daily-review-design.md docs/plans/2026-03-06-daily-review.md
```

**Step 3: Commit**

```
git add CLAUDE.md docs/design-system.md
git rm docs/plans/2026-03-06-daily-review-design.md docs/plans/2026-03-06-daily-review.md
git commit -m "docs: update CLAUDE.md and design system for Daily Review feature"
```

---

## Task 13: Final Verification

**Step 1: Run all backend tests**

Run: `docker-compose exec backend pytest -v --tb=short`
Expected: All pass (including new DailyReview tests)

**Step 2: Run all frontend tests**

Run: `cd frontend && npx pnpm test`
Expected: All pass

**Step 3: Run frontend lint + typecheck**

Run: `cd frontend && npx pnpm lint`
Expected: Clean (only pre-existing warnings)

**Step 4: Verify the review page works**

Run: `docker-compose up -d` and navigate to `http://localhost:3000/review`
Expected: Wizard loads with today's summary, all 6 steps work

**Step 5: Commit any final fixes**

If anything fails, fix and commit atomically.

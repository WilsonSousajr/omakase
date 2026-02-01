# Task Completion Checkbox Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add checkbox UI for task completion with bidirectional sync between `is_completed` and `kanban_status='done'` across all views.

**Architecture:** Backend `Task.save()` override enforces sync logic. Frontend uses optimistic updates via TanStack Query. Checkboxes in plan view (task list + calendar), strikethrough-only in focus view (kanban).

**Tech Stack:** Django 5.2 (backend sync), Next.js 15 + TanStack Query (optimistic UI), Tailwind CSS (styling)

---

## Task 1: Backend - Add Task Model save() Override

**Files:**
- Modify: `backend/tasks/models.py` (Task model around line 39)
- Test: Manual testing via Django shell (no pytest setup yet)

**Step 1: Add save() method to Task model**

In `backend/tasks/models.py`, add this method to the `Task` class (after line 59, before `class Meta:`):

```python
def save(self, *args, **kwargs):
    from django.utils import timezone

    # If moving to done, ensure completed
    if self.kanban_status == 'done':
        self.is_completed = True
        if not self.completed_at:
            self.completed_at = timezone.now()
    else:
        # If checked but not in done column, move to done
        if self.is_completed:
            self.kanban_status = 'done'
            if not self.completed_at:
                self.completed_at = timezone.now()
        else:
            # Unchecked or moved out of done - clear timestamp
            self.completed_at = None

    super().save(*args, **kwargs)
```

**Step 2: Test backend sync logic**

Start Django shell in Docker:
```bash
docker compose exec backend python manage.py shell
```

Test scenarios:
```python
from tasks.models import Task

# Test 1: Checking checkbox (is_completed=True) auto-sets kanban_status
task = Task.objects.create(title="Test 1", kanban_status='todo')
task.is_completed = True
task.save()
assert task.kanban_status == 'done'
assert task.completed_at is not None

# Test 2: Unchecking clears completed_at
task.is_completed = False
task.save()
assert task.completed_at is None

# Test 3: Moving to done auto-sets is_completed
task2 = Task.objects.create(title="Test 2", is_completed=False)
task2.kanban_status = 'done'
task2.save()
assert task2.is_completed == True
assert task2.completed_at is not None

# Test 4: Moving out of done clears completed_at
task2.kanban_status = 'in_progress'
task2.is_completed = False
task2.save()
assert task2.completed_at is None

print("All tests passed!")
```

Expected: All assertions pass.

**Step 3: Commit backend changes**

```bash
git add backend/tasks/models.py
git commit -m "feat(backend): add Task.save() override for completion sync

- Auto-sync is_completed with kanban_status='done'
- Set completed_at timestamp when task completed
- Clear completed_at when task uncompleted or moved out of done"
```

---

## Task 2: Frontend - Create useToggleTaskComplete Hook

**Files:**
- Modify: `frontend/src/hooks/useTasks.ts`

**Step 1: Add import for useQueryClient**

At top of `frontend/src/hooks/useTasks.ts`, ensure these imports exist:

```typescript
import { useQueryClient } from "@tanstack/react-query";
```

**Step 2: Add useToggleTaskComplete hook**

Add this export at the end of `frontend/src/hooks/useTasks.ts`:

```typescript
export function useToggleTaskComplete() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, is_completed }: { id: string; is_completed: boolean }) => {
      const response = await api.patch(`/tasks/${id}/`, { is_completed });
      return response.data;
    },
    onMutate: async ({ id, is_completed }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ["tasks"] });

      // Snapshot previous value
      const previousTasks = queryClient.getQueryData(["tasks"]);

      // Optimistically update all task queries
      queryClient.setQueriesData<Task[]>(
        { queryKey: ["tasks"] },
        (old) => old?.map(t =>
          t.id === id
            ? {
                ...t,
                is_completed,
                kanban_status: is_completed ? 'done' : 'todo',
                completed_at: is_completed ? new Date().toISOString() : null
              }
            : t
        )
      );

      return { previousTasks };
    },
    onError: (_err, _variables, context) => {
      // Rollback on error
      if (context?.previousTasks) {
        queryClient.setQueryData(["tasks"], context.previousTasks);
      }
    },
    onSettled: () => {
      // Refetch to sync with server
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
    },
  });
}
```

**Step 3: Verify TypeScript compiles**

Run linter to check for type errors:
```bash
docker compose exec frontend pnpm lint
```

Expected: No TypeScript errors related to the new hook.

**Step 4: Commit hook implementation**

```bash
git add frontend/src/hooks/useTasks.ts
git commit -m "feat(frontend): add useToggleTaskComplete hook

- Optimistic updates for is_completed field
- Auto-sync kanban_status and completed_at locally
- Invalidate tasks and timeblocks queries on settle"
```

---

## Task 3: Frontend - Add Checkbox to TaskCard Component

**Files:**
- Modify: `frontend/src/components/tasks/TaskCard.tsx`

**Step 1: Update TaskCardProps interface**

At top of `frontend/src/components/tasks/TaskCard.tsx` (around line 9), update the interface:

```typescript
interface TaskCardProps {
  task: Task;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
  onToggleComplete: (id: string, isCompleted: boolean) => void;
}
```

**Step 2: Update component signature**

Update the function signature (around line 15):

```typescript
export default function TaskCard({ task, onEdit, onDelete, onToggleComplete }: TaskCardProps) {
```

**Step 3: Add checkbox before grip icon**

Replace the return statement (starting around line 18) with:

```typescript
return (
  <div
    className={cn(
      "group flex items-start gap-2 rounded-lg border border-zinc-800 bg-zinc-900 p-3 transition-colors hover:border-zinc-700"
    )}
  >
    {/* Checkbox */}
    <button
      onClick={(e) => {
        e.stopPropagation();
        onToggleComplete(task.id, !task.is_completed);
      }}
      className="mt-0.5 shrink-0"
    >
      <div className={cn(
        "h-4 w-4 rounded border transition-all",
        task.is_completed
          ? "bg-blue-500 border-blue-500"
          : "border-zinc-600 hover:border-zinc-500"
      )}>
        {task.is_completed && (
          <svg className="h-full w-full text-white" viewBox="0 0 16 16">
            <path fill="currentColor" d="M13 4L6 11L3 8" strokeWidth="2" stroke="currentColor" />
          </svg>
        )}
      </div>
    </button>

    <div className="mt-0.5 text-zinc-600">
      <GripVertical className="h-4 w-4" />
    </div>

    <div className="min-w-0 flex-1">
      <div className="flex items-center gap-2">
        <span className={cn(
          "truncate text-sm font-medium text-zinc-200",
          task.is_completed && "line-through opacity-60"
        )}>
          {task.title}
        </span>
        {priority && (
          <span
            className="shrink-0 rounded px-1.5 py-0.5 text-[10px] font-medium"
            style={{
              backgroundColor: priority.color + "20",
              color: priority.color,
            }}
          >
            {priority.label}
          </span>
        )}
      </div>

      {task.description && (
        <p className="mt-0.5 truncate text-xs text-zinc-500">
          {task.description}
        </p>
      )}

      <div className="mt-1.5 flex items-center gap-2">
        {task.tags.map((tag) => (
          <span
            key={tag.id}
            className="rounded px-1.5 py-0.5 text-[10px]"
            style={{
              backgroundColor: tag.color + "20",
              color: tag.color,
            }}
          >
            {tag.name}
          </span>
        ))}
        {task.scheduled_date && (
          <span className="flex items-center gap-1 text-[10px] text-zinc-500">
            <Calendar className="h-3 w-3" />
            {format(new Date(task.scheduled_date + "T00:00:00"), "MMM d")}
          </span>
        )}
      </div>
    </div>

    <div className="flex shrink-0 gap-1 opacity-0 transition-opacity group-hover:opacity-100">
      <button
        onClick={() => onEdit(task)}
        onPointerDown={(e) => e.stopPropagation()}
        className="rounded p-1 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300"
      >
        <Pencil className="h-3.5 w-3.5" />
      </button>
      <button
        onClick={() => onDelete(task.id)}
        onPointerDown={(e) => e.stopPropagation()}
        className="rounded p-1 text-zinc-500 hover:bg-red-900/50 hover:text-red-400"
      >
        <Trash2 className="h-3.5 w-3.5" />
      </button>
    </div>
  </div>
);
```

**Step 4: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No TypeScript errors.

**Step 5: Commit TaskCard changes**

```bash
git add frontend/src/components/tasks/TaskCard.tsx
git commit -m "feat(frontend): add checkbox to TaskCard component

- Add checkbox button before grip icon
- Add strikethrough styling when task completed
- Add onToggleComplete prop for parent handler"
```

---

## Task 4: Frontend - Wire TaskCard Checkbox in TaskList

**Files:**
- Modify: `frontend/src/components/tasks/TaskList.tsx`

**Step 1: Import useToggleTaskComplete hook**

At top of `frontend/src/components/tasks/TaskList.tsx`, add import:

```typescript
import { useToggleTaskComplete } from "@/hooks/useTasks";
```

**Step 2: Initialize hook in component**

Inside the `TaskList` component (after other hooks), add:

```typescript
const toggleComplete = useToggleTaskComplete();
```

**Step 3: Add handler function**

Add this function inside the component:

```typescript
const handleToggleComplete = (id: string, isCompleted: boolean) => {
  toggleComplete.mutate({ id, is_completed: isCompleted });
};
```

**Step 4: Pass handler to TaskCard**

Find where `TaskCard` is rendered (likely in a map) and add the prop:

```typescript
<TaskCard
  task={task}
  onEdit={handleEdit}
  onDelete={handleDelete}
  onToggleComplete={handleToggleComplete}
/>
```

**Step 5: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No errors.

**Step 6: Commit TaskList changes**

```bash
git add frontend/src/components/tasks/TaskList.tsx
git commit -m "feat(frontend): wire checkbox handler in TaskList

- Initialize useToggleTaskComplete hook
- Pass handler to TaskCard component"
```

---

## Task 5: Frontend - Wire TaskCard Checkbox in DraggableTaskCard

**Files:**
- Modify: `frontend/src/components/tasks/DraggableTaskCard.tsx`

**Step 1: Check if DraggableTaskCard uses TaskCard**

Read `frontend/src/components/tasks/DraggableTaskCard.tsx` to see if it wraps TaskCard.

**Step 2: Update DraggableTaskCardProps interface**

Add `onToggleComplete` to the props interface:

```typescript
interface DraggableTaskCardProps {
  task: Task;
  onEdit: (task: Task) => void;
  onDelete: (id: string) => void;
  onToggleComplete: (id: string, isCompleted: boolean) => void;
}
```

**Step 3: Pass prop to TaskCard**

In the component, pass the prop through:

```typescript
<TaskCard
  task={task}
  onEdit={onEdit}
  onDelete={onDelete}
  onToggleComplete={onToggleComplete}
/>
```

**Step 4: Update parent component (plan page)**

Find where `DraggableTaskCard` is used (likely in `frontend/src/app/plan/page.tsx`), import `useToggleTaskComplete`, and pass the handler.

**Step 5: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No errors.

**Step 6: Commit changes**

```bash
git add frontend/src/components/tasks/DraggableTaskCard.tsx frontend/src/app/plan/page.tsx
git commit -m "feat(frontend): wire checkbox in DraggableTaskCard

- Pass onToggleComplete prop through wrapper
- Connect handler in plan page"
```

---

## Task 6: Frontend - Add Checkbox to TimeBlockItem

**Files:**
- Modify: `frontend/src/components/calendar/TimeBlockItem.tsx`

**Step 1: Update TimeBlockItemProps interface**

Add optional prop (around line 10):

```typescript
interface TimeBlockItemProps {
  block: TimeBlock;
  task?: Task;
  onDelete: (id: string) => void;
  onResize: (id: string, newEndTime: string) => void;
  onToggleComplete?: (id: string, isCompleted: boolean) => void;
  slotHeight: number;
}
```

**Step 2: Update component signature**

Around line 30, update destructuring:

```typescript
export default function TimeBlockItem({
  block,
  task,
  onDelete,
  onResize,
  onToggleComplete,
  slotHeight,
}: TimeBlockItemProps) {
```

**Step 3: Add checkbox to time block**

Inside the time block div (around line 127), replace the content with:

```tsx
<div className="flex items-start justify-between">
  {/* Checkbox */}
  <button
    onClick={(e) => {
      e.stopPropagation();
      if (task?.id) {
        onToggleComplete?.(task.id, !task.is_completed);
      }
    }}
    onPointerDown={(e) => e.stopPropagation()}
    className="mr-1.5 mt-0.5 shrink-0"
  >
    <div className={cn(
      "h-3.5 w-3.5 rounded border transition-all",
      task?.is_completed
        ? "bg-blue-500 border-blue-500"
        : "border-current opacity-50 hover:opacity-100"
    )}
    style={{ borderColor: color }}
    >
      {task?.is_completed && (
        <svg className="h-full w-full text-white" viewBox="0 0 16 16">
          <path fill="currentColor" d="M13 4L6 11L3 8" strokeWidth="2.5" stroke="currentColor" />
        </svg>
      )}
    </div>
  </button>

  <div className="min-w-0 flex-1">
    <div className="flex items-center gap-1.5">
      <p className={cn(
        "truncate text-xs font-medium",
        task?.is_completed && "line-through opacity-60"
      )}
      style={{ color }}>
        {task?.title || "Task"}
      </p>
      {priority && (
        <span
          className="shrink-0 rounded px-1 py-0.5 text-[9px] font-semibold leading-none"
          style={{
            backgroundColor: `${color}25`,
            color,
          }}
        >
          {priority.label}
        </span>
      )}
    </div>
    <p className="text-[10px]" style={{ color: `${color}90` }}>
      {block.start_time.slice(0, 5)} – {block.end_time.slice(0, 5)}
    </p>
  </div>

  <button
    onClick={(e) => {
      e.stopPropagation();
      onDelete(block.id);
    }}
    className="shrink-0 rounded p-0.5 opacity-0 transition-opacity group-hover:opacity-100"
    style={{ color }}
    onPointerDown={(e) => e.stopPropagation()}
  >
    <X className="h-3 w-3" />
  </button>
</div>
```

**Step 4: Add cn import if missing**

At top of file, ensure import exists:

```typescript
import { cn } from "@/lib/utils";
```

**Step 5: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No errors.

**Step 6: Commit TimeBlockItem changes**

```bash
git add frontend/src/components/calendar/TimeBlockItem.tsx
git commit -m "feat(frontend): add checkbox to TimeBlockItem

- Add checkbox button at top-left of time block
- Add strikethrough styling when task completed
- Add optional onToggleComplete prop"
```

---

## Task 7: Frontend - Wire TimeBlockItem Checkbox in Calendar

**Files:**
- Modify: `frontend/src/components/calendar/CalendarDayView.tsx` or `CalendarWeekView.tsx` (whichever renders TimeBlockItem)

**Step 1: Find where TimeBlockItem is rendered**

Read both calendar view files to determine which one renders `TimeBlockItem`.

**Step 2: Import useToggleTaskComplete**

At top of the file:

```typescript
import { useToggleTaskComplete } from "@/hooks/useTasks";
```

**Step 3: Initialize hook**

Inside the component:

```typescript
const toggleComplete = useToggleTaskComplete();
```

**Step 4: Add handler function**

```typescript
const handleToggleComplete = (id: string, isCompleted: boolean) => {
  toggleComplete.mutate({ id, is_completed: isCompleted });
};
```

**Step 5: Pass handler to TimeBlockItem**

```typescript
<TimeBlockItem
  block={block}
  task={task}
  onDelete={handleDelete}
  onResize={handleResize}
  onToggleComplete={handleToggleComplete}
  slotHeight={slotHeight}
/>
```

**Step 6: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No errors.

**Step 7: Commit calendar changes**

```bash
git add frontend/src/components/calendar/*.tsx
git commit -m "feat(frontend): wire checkbox in calendar views

- Initialize useToggleTaskComplete in calendar
- Pass handler to TimeBlockItem"
```

---

## Task 8: Frontend - Add Strikethrough to KanbanCard

**Files:**
- Modify: `frontend/src/components/kanban/KanbanCard.tsx`

**Step 1: Add strikethrough styling to task title**

Find the task title span (around line 61) and update:

```typescript
<span className={cn(
  "truncate text-sm font-medium text-zinc-200",
  task.is_completed && "line-through opacity-60"
)}>
  {task.title}
</span>
```

**Step 2: Verify TypeScript compiles**

```bash
docker compose exec frontend pnpm lint
```

Expected: No errors.

**Step 3: Commit KanbanCard changes**

```bash
git add frontend/src/components/kanban/KanbanCard.tsx
git commit -m "feat(frontend): add strikethrough to KanbanCard

- Show line-through styling when task completed
- No checkbox in kanban view (design requirement)"
```

---

## Task 9: Manual Testing - End-to-End Verification

**Files:**
- None (testing only)

**Step 1: Start the application**

```bash
docker compose up
```

Wait for all services to be healthy.

**Step 2: Create a test task**

Open browser to `http://localhost:3000/plan`
- Click "New Task" button (keyboard: N)
- Create a task titled "Test Completion"
- Save the task

**Step 3: Test checkbox in task list**

- Click the checkbox next to "Test Completion"
- **Expected**:
  - Checkbox becomes checked (blue background)
  - Task title shows strikethrough
  - Task appears in calendar (if scheduled)

**Step 4: Test calendar checkbox sync**

- If task has a time block, click checkbox in calendar
- **Expected**: Checkbox in task list also toggles

**Step 5: Test unchecking**

- Click checkbox again to uncheck
- **Expected**:
  - Checkbox becomes unchecked
  - Strikethrough removed
  - Task still visible (not deleted)

**Step 6: Test kanban sync**

- Navigate to `http://localhost:3000/focus`
- Drag "Test Completion" to "Done" column
- **Expected**: Task shows strikethrough
- Navigate back to `/plan`
- **Expected**: Checkbox is checked in task list

**Step 7: Test kanban uncheck sync**

- In focus view, drag task from "Done" to "To Do"
- **Expected**: Strikethrough removed
- Navigate to `/plan`
- **Expected**: Checkbox is unchecked

**Step 8: Document test results**

If all tests pass, proceed to commit. If any fail, note the failure and fix before committing.

**Step 9: Commit test verification**

```bash
git commit --allow-empty -m "test: verify checkbox completion feature

Manual test scenarios passed:
- Checkbox toggle in task list
- Checkbox toggle in calendar time block
- Strikethrough styling in all views
- Kanban drag to/from Done syncs checkbox
- Optimistic updates work correctly"
```

---

## Task 10: Final Cleanup and Documentation

**Files:**
- Update: `CLAUDE.md`
- Create: git tag

**Step 1: Update CLAUDE.md with feature notes**

Add to the "Key Patterns" section in `CLAUDE.md`:

```markdown
## Task Completion

- Tasks have `is_completed` boolean and `completed_at` timestamp
- Backend auto-syncs: `kanban_status='done'` ↔ `is_completed=True`
- Checking checkbox moves task to Done, unchecking moves to To Do
- Checkboxes in plan view (task list + calendar), strikethrough-only in focus view
- `useToggleTaskComplete` hook handles optimistic updates
```

**Step 2: Verify all files are committed**

```bash
git status
```

Expected: "nothing to commit, working tree clean"

**Step 3: Commit CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with completion feature

- Document task completion checkbox behavior
- Note backend sync logic and frontend hooks"
```

**Step 4: Create feature completion tag**

```bash
git tag -a v0.1.0-task-completion -m "Feature: Task completion checkboxes

- Checkbox UI in plan view (task list + calendar)
- Strikethrough styling in all views when completed
- Backend bidirectional sync between is_completed and kanban_status
- Optimistic updates via TanStack Query"
```

**Step 5: Review commit history**

```bash
git log --oneline
```

Expected: Clean, logical commit history following conventional commits.

---

## Completion Checklist

- [ ] Backend save() override implemented and tested
- [ ] useToggleTaskComplete hook created
- [ ] TaskCard checkbox added and wired
- [ ] TimeBlockItem checkbox added and wired
- [ ] KanbanCard strikethrough added
- [ ] Manual E2E testing completed
- [ ] CLAUDE.md updated
- [ ] All changes committed with good messages
- [ ] Feature tagged

## Next Steps After Implementation

Use @superpowers:finishing-a-development-branch to:
1. Review implementation against design
2. Choose merge strategy (PR vs direct merge)
3. Clean up worktree

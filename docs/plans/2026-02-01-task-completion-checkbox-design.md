# Task Completion Checkbox Design

**Date:** 2026-02-01
**Feature:** Checkbox-based task completion with cross-view synchronization

## Overview

Add checkbox UI for marking tasks as complete with bidirectional sync between `is_completed` status and `kanban_status='done'`. Completed tasks display with strikethrough styling across all views.

## Requirements

### Checkbox Placement
- ✅ **Plan view task list**: Checkbox visible on every task card
- ✅ **Plan view calendar**: Checkbox always visible on time blocks
- ❌ **Focus view kanban**: NO checkbox (strikethrough only)

### Behavior

**Checking checkbox:**
- Sets `is_completed = True`
- Sets `kanban_status = 'done'`
- Sets `completed_at = now()`
- Shows strikethrough on task title across all views

**Unchecking checkbox:**
- Sets `is_completed = False`
- Sets `kanban_status = 'todo'` (always returns to To Do)
- Clears `completed_at = None`
- Removes strikethrough styling

**Moving to Done kanban column:**
- Sets `kanban_status = 'done'`
- Backend auto-syncs: `is_completed = True`, `completed_at = now()`
- Checkbox becomes checked in plan view
- Shows strikethrough everywhere

**Moving out of Done kanban column:**
- Sets `kanban_status = 'todo'` or `'in_progress'`
- Backend auto-syncs: `is_completed = False`, `completed_at = None`
- Checkbox becomes unchecked in plan view
- Removes strikethrough

## Architecture

### Backend Logic (Django)

**Override `Task.save()` method** to enforce bidirectional sync:

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

**Why backend logic?**
- Single source of truth - impossible to create inconsistent state
- Frontend only updates one field, backend syncs the rest
- No API changes needed (serializers already expose `is_completed`, `completed_at`)

### Frontend Changes

#### 1. Task Card Checkbox (TaskCard.tsx)

Add checkbox before the grip icon:

```tsx
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

{/* Task title with strikethrough */}
<span className={cn(
  "truncate text-sm font-medium text-zinc-200",
  task.is_completed && "line-through opacity-60"
)}>
  {task.title}
</span>
```

**Props update:** Add `onToggleComplete: (id: string, isCompleted: boolean) => void`

#### 2. Time Block Checkbox (TimeBlockItem.tsx)

Add checkbox at top-left (always visible):

```tsx
{/* Checkbox */}
<button
  onClick={(e) => {
    e.stopPropagation();
    onToggleComplete?.(task?.id, !task?.is_completed);
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

{/* Task title with strikethrough */}
<p className={cn(
  "truncate text-xs font-medium",
  task?.is_completed && "line-through opacity-60"
)}
style={{ color }}>
  {task?.title || "Task"}
</p>
```

**Props update:** Add optional `onToggleComplete?: (id: string, isCompleted: boolean) => void`

#### 3. Kanban Card Strikethrough (KanbanCard.tsx)

No checkbox, only strikethrough styling:

```tsx
<span className={cn(
  "truncate text-sm font-medium text-zinc-200",
  task.is_completed && "line-through opacity-60"
)}>
  {task.title}
</span>
```

**No changes needed to KanbanBoard.tsx** - backend auto-syncs `is_completed` when `kanban_status` changes.

#### 4. Optimistic Updates Hook

Create `useToggleTaskComplete` in `hooks/useTasks.ts`:

```tsx
export function useToggleTaskComplete() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, is_completed }: { id: string; is_completed: boolean }) => {
      const response = await api.patch(`/tasks/${id}/`, { is_completed });
      return response.data;
    },
    onMutate: async ({ id, is_completed }) => {
      await queryClient.cancelQueries({ queryKey: ["tasks"] });
      const previousTasks = queryClient.getQueryData(["tasks"]);

      // Optimistically update: sync kanban_status locally to match backend logic
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
    onError: (err, variables, context) => {
      queryClient.setQueryData(["tasks"], context?.previousTasks);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      queryClient.invalidateQueries({ queryKey: ["timeblocks"] });
    },
  });
}
```

**Why invalidate timeblocks?** Calendar displays tasks nested inside time blocks - must refetch to show updated completion state.

## Implementation Checklist

### Backend
- [ ] Override `Task.save()` method with sync logic
- [ ] Test bidirectional sync with unit tests
- [ ] Verify `completed_at` timestamp behavior

### Frontend - Components
- [ ] Add checkbox to `TaskCard.tsx` with strikethrough
- [ ] Add checkbox to `TimeBlockItem.tsx` with strikethrough
- [ ] Add strikethrough only to `KanbanCard.tsx`

### Frontend - Hooks
- [ ] Create `useToggleTaskComplete` hook with optimistic updates
- [ ] Wire up checkbox handlers in parent components
- [ ] Test cache invalidation across views

### Testing
- [ ] Click checkbox in task list → verify strikethrough + kanban moves to Done
- [ ] Uncheck checkbox → verify returns to To Do
- [ ] Drag task to Done column → verify checkbox auto-checks
- [ ] Drag task out of Done → verify checkbox auto-unchecks
- [ ] Calendar time block checkbox → verify syncs with task list
- [ ] Verify all views update simultaneously (plan list, calendar, kanban)

## Edge Cases

1. **Task already in Done column, uncheck checkbox** → Moves to To Do (not In Progress)
2. **Task in To Do, check checkbox** → Moves to Done (skips In Progress)
3. **Network failure during checkbox click** → Optimistic update rolls back
4. **Multiple time blocks for same task** → All blocks update simultaneously via cache invalidation

## Future Enhancements

- Filter view: "Show completed tasks" toggle
- Analytics: "Tasks completed this week" metric using `completed_at`
- Keyboard shortcut: Press `C` to toggle completion of selected task

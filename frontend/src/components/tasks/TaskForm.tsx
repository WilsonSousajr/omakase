"use client";

import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { PRIORITIES, AREAS } from "@/lib/constants";
import { useTags } from "@/hooks/useTags";
import { useCreateTask, useUpdateTask } from "@/hooks/useTasks";
import { useUIStore } from "@/stores/uiStore";
import type { Task } from "@/types/task";
import type { Priority, Area } from "@/lib/constants";

interface TaskFormProps {
  editTask?: Task | null;
  onClose: () => void;
}

export default function TaskForm({ editTask, onClose }: TaskFormProps) {
  const { modalOpen } = useUIStore();
  const { data: tags = [] } = useTags();
  const createTask = useCreateTask();
  const updateTask = useUpdateTask();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<Priority>("medium");
  const [area, setArea] = useState<Area>("work");
  const [selectedTagIds, setSelectedTagIds] = useState<string[]>([]);
  const [scheduledDate, setScheduledDate] = useState("");
  const [dueDate, setDueDate] = useState("");
  const [estimatedMinutes, setEstimatedMinutes] = useState("");

  useEffect(() => {
    if (editTask) {
      setTitle(editTask.title);
      setDescription(editTask.description || "");
      setPriority(editTask.priority);
      setArea(editTask.area);
      setSelectedTagIds(editTask.tags.map((t) => t.id));
      setScheduledDate(editTask.scheduled_date || "");
      setDueDate(editTask.due_date || "");
      setEstimatedMinutes(editTask.estimated_minutes?.toString() || "");
    }
  }, [editTask]);

  if (modalOpen !== "task-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const payload = {
      title: title.trim(),
      description,
      priority,
      area,
      tag_ids: selectedTagIds,
      scheduled_date: scheduledDate || null,
      due_date: dueDate || null,
      estimated_minutes: estimatedMinutes ? parseInt(estimatedMinutes) : null,
    };

    if (editTask) {
      await updateTask.mutateAsync({ id: editTask.id, ...payload });
    } else {
      await createTask.mutateAsync(payload);
    }
    onClose();
  };

  const toggleTag = (id: string) => {
    setSelectedTagIds((prev) =>
      prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-xl border border-zinc-800 bg-zinc-900 shadow-2xl">
        <div className="flex items-center justify-between border-b border-zinc-800 px-5 py-3">
          <h3 className="text-sm font-medium text-zinc-200">
            {editTask ? "Edit Task" : "New Task"}
          </h3>
          <button
            onClick={onClose}
            className="rounded p-1 text-zinc-500 hover:bg-zinc-800 hover:text-zinc-300"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-5">
          <div>
            <input
              type="text"
              placeholder="Task title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-indigo-500"
            />
          </div>

          <div>
            <textarea
              placeholder="Description (optional)"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 outline-none focus:border-indigo-500"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-xs text-zinc-500">Priority</label>
              <select
                value={priority}
                onChange={(e) => setPriority(e.target.value as Priority)}
                className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-1.5 text-sm text-zinc-300 outline-none focus:border-indigo-500"
              >
                {PRIORITIES.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-xs text-zinc-500">Area</label>
              <select
                value={area}
                onChange={(e) => setArea(e.target.value as Area)}
                className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-1.5 text-sm text-zinc-300 outline-none focus:border-indigo-500"
              >
                {AREAS.map((a) => (
                  <option key={a.value} value={a.value}>
                    {a.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-xs text-zinc-500">Scheduled Date</label>
              <input
                type="date"
                value={scheduledDate}
                onChange={(e) => setScheduledDate(e.target.value)}
                className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-1.5 text-sm text-zinc-300 outline-none focus:border-indigo-500"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-xs text-zinc-500">Due Date</label>
              <input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-1.5 text-sm text-zinc-300 outline-none focus:border-indigo-500"
              />
            </div>
            <div className="w-24">
              <label className="mb-1 block text-xs text-zinc-500">Est. (min)</label>
              <input
                type="number"
                min="0"
                value={estimatedMinutes}
                onChange={(e) => setEstimatedMinutes(e.target.value)}
                className="w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-1.5 text-sm text-zinc-300 outline-none focus:border-indigo-500"
              />
            </div>
          </div>

          {tags.length > 0 && (
            <div>
              <label className="mb-1.5 block text-xs text-zinc-500">Tags</label>
              <div className="flex flex-wrap gap-1.5">
                {tags.map((tag) => (
                  <button
                    key={tag.id}
                    type="button"
                    onClick={() => toggleTag(tag.id)}
                    className="rounded-full px-2.5 py-1 text-xs transition-colors"
                    style={{
                      backgroundColor: selectedTagIds.includes(tag.id)
                        ? tag.color + "30"
                        : "transparent",
                      color: selectedTagIds.includes(tag.id)
                        ? tag.color
                        : "#a1a1aa",
                      border: `1px solid ${
                        selectedTagIds.includes(tag.id)
                          ? tag.color + "60"
                          : "#3f3f46"
                      }`,
                    }}
                  >
                    {tag.name}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded-md px-3 py-1.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!title.trim() || createTask.isPending || updateTask.isPending}
              className="rounded-md bg-indigo-600 px-4 py-1.5 text-xs font-medium text-white transition-colors hover:bg-indigo-500 disabled:opacity-50"
            >
              {editTask ? "Update" : "Create"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

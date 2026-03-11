"use client";

import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { useTranslations } from "next-intl";
import { PROJECT_STATUSES } from "@/lib/constants";
import ColorSwatchPicker from "@/components/ColorSwatchPicker";
import { useWorkspaces } from "@/hooks/useWorkspaces";
import { useCreateProject, useUpdateProject } from "@/hooks/useProjects";
import { useUIStore } from "@/stores/uiStore";
import type { Project } from "@/types/project";
import type { ProjectStatus } from "@/lib/constants";

interface ProjectFormProps {
  editProject?: Project | null;
  onClose: () => void;
}

export default function ProjectForm({ editProject, onClose }: ProjectFormProps) {
  const t = useTranslations("projects");
  const tc = useTranslations("common");
  const tConst = useTranslations("constants");
  const modalOpen = useUIStore((s) => s.modalOpen);
  const { data: workspaces = [] } = useWorkspaces();
  const createProject = useCreateProject();
  const updateProject = useUpdateProject();

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [workspaceId, setWorkspaceId] = useState("");
  const [color, setColor] = useState("#a3a3a3");
  const [status, setStatus] = useState<ProjectStatus>("active");
  const [dueDate, setDueDate] = useState("");

  useEffect(() => {
    if (editProject) {
      setName(editProject.name);
      setDescription(editProject.description || "");
      setWorkspaceId(editProject.workspace);
      setColor(editProject.color);
      setStatus(editProject.status);
      setDueDate(editProject.due_date || "");
    } else {
      setName("");
      setDescription("");
      setColor("#a3a3a3");
      setStatus("active");
      setDueDate("");
    }
  }, [editProject]);

  // Separate effect for default workspace (only when creating)
  useEffect(() => {
    if (!editProject && workspaces.length > 0 && !workspaceId) {
      setWorkspaceId(workspaces[0].id);
    }
  }, [editProject, workspaces, workspaceId]);

  if (modalOpen !== "project-form") return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !workspaceId) return;

    const payload = {
      name: name.trim(),
      description,
      workspace: workspaceId,
      color,
      status,
      due_date: dueDate || null,
    };

    if (editProject) {
      await updateProject.mutateAsync({ id: editProject.id, ...payload });
    } else {
      await createProject.mutateAsync(payload);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="w-full max-w-lg rounded-2xl border border-[var(--color-border)] bg-[var(--color-surface-elevated)] shadow-2xl">
        <div className="flex items-center justify-between border-b border-[var(--color-border)] px-6 py-4">
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            {editProject ? t("editProject") : t("newProject")}
          </h3>
          <button
            onClick={onClose}
            className="rounded-lg p-1 text-[var(--color-text-faint)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-secondary)]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4 p-6">
          <div>
            <input
              type="text"
              placeholder={t("namePlaceholder")}
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div>
            <textarea
              placeholder={t("descriptionPlaceholder")}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("workspace")}
              </label>
              <select
                value={workspaceId}
                onChange={(e) => setWorkspaceId(e.target.value)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                <option value="">{t("workspace")}</option>
                {workspaces.map((ws) => (
                  <option key={ws.id} value={ws.id}>
                    {ws.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                {t("status")}
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as ProjectStatus)}
                className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
              >
                {PROJECT_STATUSES.map((s) => (
                  <option key={s.value} value={s.value}>
                    {tConst(`projectStatuses.${s.value}`)}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <ColorSwatchPicker value={color} onChange={setColor} />

          <div>
            <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
              {t("dueDate")}
            </label>
            <input
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-3.5 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl px-3 py-1.5 text-xs text-[var(--color-text-secondary)] hover:bg-[var(--color-hover-overlay)] hover:text-[var(--color-text-primary)]"
            >
              {tc("cancel")}
            </button>
            <button
              type="submit"
              disabled={!name.trim() || !workspaceId || createProject.isPending || updateProject.isPending}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)] disabled:opacity-50"
            >
              {editProject ? tc("update") : tc("create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

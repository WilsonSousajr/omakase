"use client";

import { useState, useMemo, useRef } from "react";
import { Plus, Pencil, Trash2, X, Check } from "lucide-react";
import { useTranslations } from "next-intl";
import { cn } from "@/lib/utils";
import { PROJECT_STATUSES } from "@/lib/constants";
import { useProjects, useDeleteProject } from "@/hooks/useProjects";
import { useWorkspaces, useCreateWorkspace, useUpdateWorkspace, useDeleteWorkspace } from "@/hooks/useWorkspaces";
import { useUIStore } from "@/stores/uiStore";
import ProjectCard from "@/components/projects/ProjectCard";
import ProjectForm from "@/components/projects/ProjectForm";
import type { Project } from "@/types/project";

export default function ProjectsPage() {
  const t = useTranslations("projects");
  const tc = useTranslations("common");
  const tConst = useTranslations("constants");
  const activeWorkspaceId = useUIStore((s) => s.activeWorkspaceId);
  const setActiveWorkspaceId = useUIStore((s) => s.setActiveWorkspaceId);
  const openModal = useUIStore((s) => s.openModal);
  const closeModal = useUIStore((s) => s.closeModal);
  const { data: workspaces = [] } = useWorkspaces();
  const createWorkspace = useCreateWorkspace();
  const updateWorkspace = useUpdateWorkspace();
  const deleteWorkspace = useDeleteWorkspace();
  const { data: projects = [], isLoading } = useProjects(
    activeWorkspaceId ? { workspace: activeWorkspaceId } : undefined
  );
  const deleteProject = useDeleteProject();
  const [editProject, setEditProject] = useState<Project | null>(null);
  const [newWorkspaceName, setNewWorkspaceName] = useState("");
  const [showNewWorkspace, setShowNewWorkspace] = useState(false);
  const [editingWorkspaceId, setEditingWorkspaceId] = useState<string | null>(null);
  const [editingWorkspaceName, setEditingWorkspaceName] = useState("");
  const newWsInputRef = useRef<HTMLInputElement>(null);
  const editWsInputRef = useRef<HTMLInputElement>(null);

  const grouped = useMemo(() => {
    const map = new Map<string, Project[]>();
    for (const status of PROJECT_STATUSES) {
      map.set(status.value, []);
    }
    for (const project of projects) {
      const list = map.get(project.status);
      if (list) list.push(project);
    }
    return map;
  }, [projects]);

  const handleCreateWorkspace = async () => {
    if (!newWorkspaceName.trim()) return;
    const ws = await createWorkspace.mutateAsync({ name: newWorkspaceName.trim() });
    setNewWorkspaceName("");
    setShowNewWorkspace(false);
    setActiveWorkspaceId(ws.id);
  };

  const handleStartEditWorkspace = (id: string, name: string) => {
    setEditingWorkspaceId(id);
    setEditingWorkspaceName(name);
    setTimeout(() => editWsInputRef.current?.focus(), 0);
  };

  const handleSaveEditWorkspace = async () => {
    if (!editingWorkspaceId || !editingWorkspaceName.trim()) return;
    await updateWorkspace.mutateAsync({ id: editingWorkspaceId, name: editingWorkspaceName.trim() });
    setEditingWorkspaceId(null);
  };

  const handleDeleteWorkspace = async (id: string) => {
    await deleteWorkspace.mutateAsync(id);
    if (activeWorkspaceId === id) setActiveWorkspaceId(null);
  };

  const handleNew = () => {
    setEditProject(null);
    openModal("project-form");
  };

  const handleEdit = (project: Project) => {
    setEditProject(project);
    openModal("project-form");
  };

  const handleDelete = async (id: string) => {
    await deleteProject.mutateAsync(id);
  };

  const handleClose = () => {
    setEditProject(null);
    closeModal();
  };

  return (
    <div className="h-full overflow-auto p-6">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">{t("title")}</h1>
        <button
          onClick={handleNew}
          className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          <Plus className="h-3.5 w-3.5" />
          {t("newProject")}
        </button>
      </div>

      {/* Workspace selector bar */}
      <div className="mb-6">
        <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
          {t("workspaces")}
        </label>
        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => setActiveWorkspaceId(null)}
            className={cn(
              "rounded-xl px-3 py-1.5 text-xs font-medium transition-colors",
              !activeWorkspaceId
                ? "bg-[var(--color-surface-active)] text-[var(--color-text-primary)]"
                : "text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
            )}
          >
            {t("all")}
          </button>
          {workspaces.map((ws) => (
            <div key={ws.id} className="group flex items-center">
              {editingWorkspaceId === ws.id ? (
                <div className="flex items-center gap-1">
                  <input
                    ref={editWsInputRef}
                    type="text"
                    value={editingWorkspaceName}
                    onChange={(e) => setEditingWorkspaceName(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") handleSaveEditWorkspace();
                      if (e.key === "Escape") setEditingWorkspaceId(null);
                    }}
                    className="w-24 rounded-lg border border-[var(--color-border)] bg-[var(--color-input)] px-2 py-1 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
                  />
                  <button onClick={handleSaveEditWorkspace} className="rounded p-0.5 text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]">
                    <Check className="h-3.5 w-3.5" />
                  </button>
                  <button onClick={() => setEditingWorkspaceId(null)} className="rounded p-0.5 text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]">
                    <X className="h-3.5 w-3.5" />
                  </button>
                </div>
              ) : (
                <>
                  <button
                    onClick={() => setActiveWorkspaceId(activeWorkspaceId === ws.id ? null : ws.id)}
                    className={cn(
                      "rounded-xl px-3 py-1.5 text-xs font-medium transition-colors",
                      activeWorkspaceId === ws.id
                        ? "bg-[var(--color-surface-active)] text-[var(--color-text-primary)]"
                        : "text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
                    )}
                  >
                    {ws.name}
                    <span className="ml-1.5 text-[var(--color-text-faint)]">{ws.project_count}</span>
                  </button>
                  <div className="ml-0.5 flex items-center opacity-0 transition-opacity group-hover:opacity-100">
                    <button
                      onClick={() => handleStartEditWorkspace(ws.id, ws.name)}
                      className="rounded p-0.5 text-[var(--color-text-faint)] hover:text-[var(--color-text-secondary)]"
                    >
                      <Pencil className="h-3 w-3" />
                    </button>
                    <button
                      onClick={() => handleDeleteWorkspace(ws.id)}
                      className="rounded p-0.5 text-[var(--color-text-faint)] hover:text-red-400"
                    >
                      <Trash2 className="h-3 w-3" />
                    </button>
                  </div>
                </>
              )}
            </div>
          ))}

          {showNewWorkspace ? (
            <div className="flex items-center gap-1">
              <input
                ref={newWsInputRef}
                type="text"
                placeholder={t("workspaceNamePlaceholder")}
                value={newWorkspaceName}
                onChange={(e) => setNewWorkspaceName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleCreateWorkspace();
                  if (e.key === "Escape") { setShowNewWorkspace(false); setNewWorkspaceName(""); }
                }}
                autoFocus
                className="w-24 rounded-lg border border-[var(--color-border)] bg-[var(--color-input)] px-2 py-1 text-xs text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-text-secondary)]/40"
              />
              <button
                onClick={handleCreateWorkspace}
                disabled={!newWorkspaceName.trim() || createWorkspace.isPending}
                className="rounded p-0.5 text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] disabled:opacity-50"
              >
                <Check className="h-3.5 w-3.5" />
              </button>
              <button
                onClick={() => { setShowNewWorkspace(false); setNewWorkspaceName(""); }}
                className="rounded p-0.5 text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          ) : (
            <button
              onClick={() => setShowNewWorkspace(true)}
              className="flex items-center gap-1 rounded-xl px-2.5 py-1.5 text-xs text-[var(--color-text-faint)] transition-colors hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
            >
              <Plus className="h-3.5 w-3.5" />
              {t("new")}
            </button>
          )}
        </div>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <span className="text-sm text-[var(--color-text-muted)]">{tc("loading")}</span>
        </div>
      ) : projects.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12">
          <p className="text-sm text-[var(--color-text-muted)]">{t("noProjects")}</p>
        </div>
      ) : (
        <div className="space-y-8">
          {PROJECT_STATUSES.map((statusDef) => {
            const items = grouped.get(statusDef.value) || [];
            if (items.length === 0) return null;
            return (
              <section key={statusDef.value}>
                <h2 className="mb-3 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                  {tConst(`projectStatuses.${statusDef.value}`)}
                  <span className="ml-2 text-[var(--color-text-faint)]">{items.length}</span>
                </h2>
                <div className="grid gap-2">
                  {items.map((project) => (
                    <ProjectCard
                      key={project.id}
                      project={project}
                      onEdit={handleEdit}
                      onDelete={handleDelete}
                    />
                  ))}
                </div>
              </section>
            );
          })}
        </div>
      )}

      <ProjectForm editProject={editProject} onClose={handleClose} />
    </div>
  );
}

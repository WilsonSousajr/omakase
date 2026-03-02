"use client";

import { useState, useMemo } from "react";
import { Plus } from "lucide-react";
import { PROJECT_STATUSES } from "@/lib/constants";
import { useProjects, useDeleteProject } from "@/hooks/useProjects";
import { useUIStore } from "@/stores/uiStore";
import ProjectCard from "@/components/projects/ProjectCard";
import ProjectForm from "@/components/projects/ProjectForm";
import type { Project } from "@/types/project";

export default function ProjectsPage() {
  const activeWorkspaceId = useUIStore((s) => s.activeWorkspaceId);
  const openModal = useUIStore((s) => s.openModal);
  const closeModal = useUIStore((s) => s.closeModal);
  const { data: projects = [], isLoading } = useProjects(
    activeWorkspaceId ? { workspace: activeWorkspaceId } : undefined
  );
  const deleteProject = useDeleteProject();
  const [editProject, setEditProject] = useState<Project | null>(null);

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
        <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Projects</h1>
        <button
          onClick={handleNew}
          className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          <Plus className="h-3.5 w-3.5" />
          New Project
        </button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <span className="text-sm text-[var(--color-text-muted)]">Loading projects...</span>
        </div>
      ) : projects.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12">
          <p className="text-sm text-[var(--color-text-muted)]">No projects yet</p>
          <p className="mt-1 text-xs text-[var(--color-text-faint)]">
            Create a project to organize your tasks
          </p>
        </div>
      ) : (
        <div className="space-y-8">
          {PROJECT_STATUSES.map((statusDef) => {
            const items = grouped.get(statusDef.value) || [];
            if (items.length === 0) return null;
            return (
              <section key={statusDef.value}>
                <h2 className="mb-3 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                  {statusDef.label}
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

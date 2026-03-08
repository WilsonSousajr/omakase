"use client";

import { useState, useMemo } from "react";
import { Plus } from "lucide-react";
import { useRouter } from "next/navigation";
import { DISCIPLINE_STATUSES } from "@/lib/constants";
import { useSemesters, useDeleteSemester } from "@/hooks/useSemesters";
import { useDisciplines, useDeleteDiscipline } from "@/hooks/useDisciplines";
import { useUIStore } from "@/stores/uiStore";
import SemesterCard from "@/components/study/SemesterCard";
import SemesterForm from "@/components/study/SemesterForm";
import DisciplineCard from "@/components/study/DisciplineCard";
import DisciplineForm from "@/components/study/DisciplineForm";
import type { Semester } from "@/types/semester";
import type { Discipline } from "@/types/discipline";

export default function StudyPage() {
  const router = useRouter();
  const activeSemesterId = useUIStore((s) => s.activeSemesterId);
  const setActiveSemesterId = useUIStore((s) => s.setActiveSemesterId);
  const openModal = useUIStore((s) => s.openModal);
  const closeModal = useUIStore((s) => s.closeModal);
  const { data: semesters = [], isLoading: semestersLoading } = useSemesters();
  const { data: disciplines = [], isLoading: disciplinesLoading } = useDisciplines(
    activeSemesterId ? { semester: activeSemesterId } : undefined
  );
  const deleteSemester = useDeleteSemester();
  const deleteDiscipline = useDeleteDiscipline();

  const [editSemester, setEditSemester] = useState<Semester | null>(null);
  const [editDiscipline, setEditDiscipline] = useState<Discipline | null>(null);

  const grouped = useMemo(() => {
    const map = new Map<string, Discipline[]>();
    for (const status of DISCIPLINE_STATUSES) {
      map.set(status.value, []);
    }
    for (const disc of disciplines) {
      const list = map.get(disc.status);
      if (list) list.push(disc);
    }
    return map;
  }, [disciplines]);

  const handleNewSemester = () => {
    setEditSemester(null);
    openModal("semester-form");
  };

  const handleEditSemester = (semester: Semester) => {
    setEditSemester(semester);
    openModal("semester-form");
  };

  const handleDeleteSemester = async (id: string) => {
    await deleteSemester.mutateAsync(id);
    if (activeSemesterId === id) setActiveSemesterId(null);
  };

  const handleNewDiscipline = () => {
    setEditDiscipline(null);
    openModal("discipline-form");
  };

  const handleEditDiscipline = (discipline: Discipline) => {
    setEditDiscipline(discipline);
    openModal("discipline-form");
  };

  const handleDeleteDiscipline = async (id: string) => {
    await deleteDiscipline.mutateAsync(id);
  };

  const handleCloseSemester = () => {
    setEditSemester(null);
    closeModal();
  };

  const handleCloseDiscipline = () => {
    setEditDiscipline(null);
    closeModal();
  };

  const handleDisciplineClick = (discipline: Discipline) => {
    router.push(`/study/${discipline.id}`);
  };

  const isLoading = semestersLoading || disciplinesLoading;

  return (
    <div className="h-full overflow-auto p-6">
      {/* Semesters section */}
      <div className="mb-8">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Semesters
          </h2>
          <button
            onClick={handleNewSemester}
            className="flex items-center gap-1 rounded-lg px-2 py-1 text-[10px] text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-text-secondary)]"
          >
            <Plus className="h-3 w-3" />
            Add
          </button>
        </div>
        {semesters.length === 0 && !semestersLoading ? (
          <p className="text-xs text-[var(--color-text-faint)]">No semesters yet. Create one to get started.</p>
        ) : (
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {semesters.map((semester) => (
              <div
                key={semester.id}
                className={`cursor-pointer rounded-2xl ring-2 transition-all ${
                  activeSemesterId === semester.id
                    ? "ring-[var(--color-ring-overlay)]"
                    : "ring-transparent"
                }`}
                onClick={() => setActiveSemesterId(
                  activeSemesterId === semester.id ? null : semester.id
                )}
              >
                <SemesterCard
                  semester={semester}
                  onEdit={handleEditSemester}
                  onDelete={handleDeleteSemester}
                />
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Disciplines section */}
      <div>
        <div className="mb-4 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Disciplines</h1>
          <button
            onClick={handleNewDiscipline}
            className="flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
          >
            <Plus className="h-3.5 w-3.5" />
            New Discipline
          </button>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <span className="text-sm text-[var(--color-text-muted)]">Loading...</span>
          </div>
        ) : disciplines.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12">
            <p className="text-sm text-[var(--color-text-muted)]">No disciplines yet</p>
            <p className="mt-1 text-xs text-[var(--color-text-faint)]">
              {activeSemesterId
                ? "Create a discipline to organize your study blocks"
                : "Select a semester or create a discipline"}
            </p>
          </div>
        ) : (
          <div className="space-y-8">
            {DISCIPLINE_STATUSES.map((statusDef) => {
              const items = grouped.get(statusDef.value) || [];
              if (items.length === 0) return null;
              return (
                <section key={statusDef.value}>
                  <h2 className="mb-3 text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
                    {statusDef.label}
                    <span className="ml-2 text-[var(--color-text-faint)]">{items.length}</span>
                  </h2>
                  <div className="grid gap-2">
                    {items.map((discipline) => (
                      <DisciplineCard
                        key={discipline.id}
                        discipline={discipline}
                        onEdit={handleEditDiscipline}
                        onDelete={handleDeleteDiscipline}
                        onClick={handleDisciplineClick}
                      />
                    ))}
                  </div>
                </section>
              );
            })}
          </div>
        )}
      </div>

      <SemesterForm editSemester={editSemester} onClose={handleCloseSemester} />
      <DisciplineForm
        editDiscipline={editDiscipline}
        defaultSemesterId={activeSemesterId}
        onClose={handleCloseDiscipline}
      />
    </div>
  );
}

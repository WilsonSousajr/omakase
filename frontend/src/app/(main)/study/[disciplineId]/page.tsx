"use client";

import { useState, useMemo } from "react";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Plus } from "lucide-react";
import { STUDY_BLOCK_TYPES, STUDY_BLOCK_STATUSES } from "@/lib/constants";
import { useDisciplines } from "@/hooks/useDisciplines";
import { useStudyBlocks, useUpdateStudyBlock, useDeleteStudyBlock } from "@/hooks/useStudyBlocks";
import { useUIStore } from "@/stores/uiStore";
import StudyBlockCard from "@/components/study/StudyBlockCard";
import StudyBlockForm from "@/components/study/StudyBlockForm";
import type { StudyBlock } from "@/types/studyblock";
import type { Discipline } from "@/types/discipline";

export default function DisciplineDetailPage() {
  const params = useParams();
  const router = useRouter();
  const disciplineId = params.disciplineId as string;
  const openModal = useUIStore((s) => s.openModal);
  const closeModal = useUIStore((s) => s.closeModal);

  const { data: disciplines = [] } = useDisciplines();
  const { data: studyBlocks = [], isLoading } = useStudyBlocks({ discipline: disciplineId });
  const updateStudyBlock = useUpdateStudyBlock();
  const deleteStudyBlock = useDeleteStudyBlock();

  const [editStudyBlock, setEditStudyBlock] = useState<StudyBlock | null>(null);
  const [filterType, setFilterType] = useState<string>("");
  const [filterStatus, setFilterStatus] = useState<string>("");

  const discipline = useMemo(
    () => disciplines.find((d) => d.id === disciplineId),
    [disciplines, disciplineId]
  );

  const disciplineMap = useMemo(() => {
    const map = new Map<string, Discipline>();
    for (const d of disciplines) {
      map.set(d.id, d);
    }
    return map;
  }, [disciplines]);

  const filteredBlocks = useMemo(() => {
    let blocks = studyBlocks;
    if (filterType) blocks = blocks.filter((b) => b.block_type === filterType);
    if (filterStatus) blocks = blocks.filter((b) => b.status === filterStatus);
    return blocks;
  }, [studyBlocks, filterType, filterStatus]);

  const handleNew = () => {
    setEditStudyBlock(null);
    openModal("studyblock-form");
  };

  const handleEdit = (block: StudyBlock) => {
    setEditStudyBlock(block);
    openModal("studyblock-form");
  };

  const handleDelete = async (id: string) => {
    await deleteStudyBlock.mutateAsync(id);
  };

  const handleToggleComplete = async (block: StudyBlock) => {
    await updateStudyBlock.mutateAsync({
      id: block.id,
      is_completed: !block.is_completed,
    });
  };

  const handleClose = () => {
    setEditStudyBlock(null);
    closeModal();
  };

  return (
    <div className="h-full overflow-auto p-6">
      <div className="mb-6">
        <button
          onClick={() => router.push("/study")}
          className="mb-3 flex items-center gap-1 text-xs text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]"
        >
          <ArrowLeft className="h-3 w-3" />
          Back to Study
        </button>

        <div className="flex items-center gap-3">
          {discipline && (
            <div
              className="h-4 w-4 shrink-0 rounded-full"
              style={{ backgroundColor: discipline.color }}
            />
          )}
          <div>
            <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">
              {discipline?.name || "Discipline"}
            </h1>
            {discipline?.code && (
              <p className="text-xs text-[var(--color-text-faint)]">{discipline.code}</p>
            )}
          </div>
          <button
            onClick={handleNew}
            className="ml-auto flex items-center gap-1.5 rounded-xl bg-[var(--color-button-primary)] px-3 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
          >
            <Plus className="h-3.5 w-3.5" />
            New Block
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="mb-4 flex gap-3">
        <div>
          <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Type
          </label>
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">All types</option>
            {STUDY_BLOCK_TYPES.map((t) => (
              <option key={t.value} value={t.value}>{t.label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-[10px] font-semibold uppercase tracking-[0.15em] text-[var(--color-text-muted)]">
            Status
          </label>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="rounded-xl border border-[var(--color-border)] bg-[var(--color-input)] px-2.5 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-text-secondary)]/40"
          >
            <option value="">All statuses</option>
            {STUDY_BLOCK_STATUSES.map((s) => (
              <option key={s.value} value={s.value}>{s.label}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Study blocks list */}
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <span className="text-sm text-[var(--color-text-muted)]">Loading study blocks...</span>
        </div>
      ) : filteredBlocks.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12">
          <p className="text-sm text-[var(--color-text-muted)]">No study blocks yet</p>
          <p className="mt-1 text-xs text-[var(--color-text-faint)]">
            Create study blocks to organize your study sessions
          </p>
        </div>
      ) : (
        <div className="grid gap-2">
          {filteredBlocks.map((block) => (
            <StudyBlockCard
              key={block.id}
              block={block}
              disciplines={disciplineMap}
              onEdit={handleEdit}
              onDelete={handleDelete}
              onToggleComplete={handleToggleComplete}
            />
          ))}
        </div>
      )}

      <StudyBlockForm
        editStudyBlock={editStudyBlock}
        defaultDisciplineId={disciplineId}
        onClose={handleClose}
      />
    </div>
  );
}

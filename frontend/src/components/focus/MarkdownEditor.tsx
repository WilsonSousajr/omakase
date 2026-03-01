"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeSanitize from "rehype-sanitize";
import { cn } from "@/lib/utils";
import { NOTES_DEBOUNCE_MS } from "@/lib/constants";
import { useUpdateTask } from "@/hooks/useTasks";

interface MarkdownEditorProps {
  taskId: string;
  initialContent: string;
}

export default function MarkdownEditor({ taskId, initialContent }: MarkdownEditorProps) {
  const [content, setContent] = useState(initialContent);
  const [tab, setTab] = useState<"write" | "preview">("write");
  const updateTask = useUpdateTask();
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const mutateRef = useRef(updateTask.mutate);

  useEffect(() => {
    mutateRef.current = updateTask.mutate;
  }, [updateTask.mutate]);

  useEffect(() => {
    setContent(initialContent);
  }, [initialContent]);

  const saveNotes = useCallback(
    (notes: string) => {
      mutateRef.current({ id: taskId, notes });
    },
    [taskId]
  );

  const handleChange = (value: string) => {
    setContent(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => saveNotes(value), NOTES_DEBOUNCE_MS);
  };

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  return (
    <div className="flex flex-col rounded-2xl border border-[var(--color-border)]">
      <div className="flex border-b border-[var(--color-border)]">
        {(["write", "preview"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "px-3 py-1.5 text-xs capitalize transition-colors",
              tab === t
                ? "border-b-2 border-[var(--color-text-primary)] text-[var(--color-text-primary)]"
                : "text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]"
            )}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "write" ? (
        <textarea
          value={content}
          onChange={(e) => handleChange(e.target.value)}
          placeholder="Write notes in Markdown..."
          className="min-h-[200px] flex-1 resize-none bg-transparent p-3 text-sm text-[var(--color-text-secondary)] placeholder-[var(--color-text-faint)] outline-none"
        />
      ) : (
        <div className="prose prose-sm prose-invert max-w-none p-3 prose-headings:text-[var(--color-text-primary)] prose-p:text-[var(--color-text-secondary)] prose-a:text-[var(--color-text-primary)] prose-a:underline prose-strong:text-[var(--color-text-primary)] prose-code:text-[var(--color-text-secondary)] prose-pre:bg-[var(--color-surface)]">
          {content ? (
            <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>{content}</ReactMarkdown>
          ) : (
            <p className="text-[var(--color-text-faint)]">Nothing to preview</p>
          )}
        </div>
      )}
    </div>
  );
}

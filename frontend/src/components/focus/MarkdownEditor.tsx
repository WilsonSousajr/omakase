"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { cn } from "@/lib/utils";
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

  useEffect(() => {
    setContent(initialContent);
  }, [initialContent]);

  const saveNotes = useCallback(
    (notes: string) => {
      updateTask.mutate({ id: taskId, notes });
    },
    [taskId, updateTask]
  );

  const handleChange = (value: string) => {
    setContent(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => saveNotes(value), 500);
  };

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  return (
    <div className="flex flex-col rounded-lg border border-zinc-800">
      <div className="flex border-b border-zinc-800">
        {(["write", "preview"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "px-3 py-1.5 text-xs capitalize transition-colors",
              tab === t
                ? "border-b-2 border-indigo-500 text-zinc-200"
                : "text-zinc-500 hover:text-zinc-300"
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
          className="min-h-[200px] flex-1 resize-none bg-transparent p-3 text-sm text-zinc-300 placeholder-zinc-600 outline-none"
        />
      ) : (
        <div className="prose prose-sm prose-invert max-w-none p-3 prose-headings:text-zinc-200 prose-p:text-zinc-400 prose-a:text-indigo-400 prose-strong:text-zinc-200 prose-code:text-indigo-300 prose-pre:bg-zinc-900">
          {content ? (
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
          ) : (
            <p className="text-zinc-600">Nothing to preview</p>
          )}
        </div>
      )}
    </div>
  );
}

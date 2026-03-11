"use client";

import React, { Component, type ReactNode } from "react";
import { useTranslations } from "next-intl";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  resetKey: number;
}

function ErrorFallback({ onRetry }: { onRetry: () => void }) {
  const t = useTranslations("errors");
  return (
    <div className="flex h-full items-center justify-center p-8">
      <div className="text-center">
        <h2 className="mb-2 text-lg font-semibold text-[var(--color-text-primary)]">
          {t("generic")}
        </h2>
        <p className="mb-4 text-sm text-[var(--color-text-muted)]">
          {t("unexpectedError")}
        </p>
        <button
          onClick={onRetry}
          className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
        >
          {t("tryAgain")}
        </button>
      </div>
    </div>
  );
}

export default class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, resetKey: 0 };
  }

  static getDerivedStateFromError(): Partial<State> {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return (
        <ErrorFallback
          onRetry={() => this.setState((prev) => ({ hasError: false, resetKey: prev.resetKey + 1 }))}
        />
      );
    }

    return <React.Fragment key={this.state.resetKey}>{this.props.children}</React.Fragment>;
  }
}

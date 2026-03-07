"use client";

import React, { Component, type ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  resetKey: number;
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
        <div className="flex h-full items-center justify-center p-8">
          <div className="text-center">
            <h2 className="mb-2 text-lg font-semibold text-[var(--color-text-primary)]">
              Something went wrong
            </h2>
            <p className="mb-4 text-sm text-[var(--color-text-muted)]">
              An unexpected error occurred. Try refreshing the page.
            </p>
            <button
              onClick={() => this.setState((prev) => ({ hasError: false, resetKey: prev.resetKey + 1 }))}
              className="rounded-xl bg-[var(--color-button-primary)] px-4 py-1.5 text-xs font-medium text-[var(--color-button-primary-text)] transition-colors hover:bg-[var(--color-button-primary-hover)]"
            >
              Try Again
            </button>
          </div>
        </div>
      );
    }

    return <React.Fragment key={this.state.resetKey}>{this.props.children}</React.Fragment>;
  }
}

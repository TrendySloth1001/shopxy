"use client";

import type { ButtonHTMLAttributes } from "react";

/**
 * Primary action button. Brand fill, restrained radius, clear disabled and
 * loading states (states are mandatory — CLAUDE.md §9b).
 */
export function SubmitButton({
  loading = false,
  children,
  disabled,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { loading?: boolean }) {
  return (
    <button
      type="submit"
      disabled={disabled || loading}
      aria-busy={loading}
      className="inline-flex h-12 w-full items-center justify-center rounded-button bg-brand px-lg text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
      {...props}
    >
      {loading ? "Please wait…" : children}
    </button>
  );
}

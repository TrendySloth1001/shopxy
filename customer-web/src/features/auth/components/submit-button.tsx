"use client";

import type { ButtonHTMLAttributes } from "react";

/**
 * Primary action button. Brand fill, restrained radius, clear disabled and
 * loading states (states are mandatory — CLAUDE.md §9b).
 *
 * `block` (default) stretches to the container width — correct for the single
 * primary submit of a focused `max-w-form` form (sign in / register). Pass
 * `block={false}` for settings forms embedded in a larger page, where the
 * button must size to its label and sit left-aligned (CLAUDE.md §layout).
 */
export function SubmitButton({
  loading = false,
  block = true,
  children,
  disabled,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  loading?: boolean;
  block?: boolean;
}) {
  return (
    <button
      type="submit"
      disabled={disabled || loading}
      aria-busy={loading}
      className={`inline-flex items-center justify-center rounded-button bg-brand text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled ${
        block
          ? "h-12 w-full px-lg text-label-lg"
          : "h-11 w-fit px-xl text-label-md"
      }`}
      {...props}
    >
      {loading ? "Please wait…" : children}
    </button>
  );
}

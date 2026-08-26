"use client";

import type { ButtonHTMLAttributes } from "react";

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

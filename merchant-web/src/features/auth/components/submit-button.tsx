"use client";

import type { ButtonHTMLAttributes } from "react";
import { useTranslations } from "next-intl";

export function SubmitButton({
  loading = false,
  children,
  disabled,
  pill = false,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  loading?: boolean;
  pill?: boolean;
}) {
  const t = useTranslations("auth");
  return (
    <button
      type="submit"
      disabled={disabled || loading}
      aria-busy={loading}
      className={`inline-flex h-12 w-full items-center justify-center ${
        pill ? "rounded-full" : "rounded-button"
      } bg-brand px-lg text-label-lg text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled`}
      {...props}
    >
      {loading ? t("common.pleaseWait") : children}
    </button>
  );
}

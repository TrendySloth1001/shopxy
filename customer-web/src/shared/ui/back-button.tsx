"use client";

import { useRouter } from "next/navigation";
import { ChevronLeft } from "@/shared/icons";

interface BackButtonProps {
  fallback: string;
  label?: string;
  className?: string;
}

export function BackButton({ fallback, label = "Back", className = "" }: BackButtonProps) {
  const router = useRouter();

  function handleClick() {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else {
      router.push(fallback);
    }
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      className={[
        "inline-flex h-9 items-center gap-xs rounded-button px-xs",
        "text-label-md text-muted",
        "hover:bg-surface-tint",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand",
        "transition-colors",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <ChevronLeft size={16} aria-hidden />
      {label}
    </button>
  );
}

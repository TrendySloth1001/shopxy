"use client";

import { useRouter } from "next/navigation";
import { ChevronLeft } from "@/shared/icons";

interface BackButtonProps {
  /** Fallback route when there is no in-app history (e.g. direct link). */
  fallback: string;
  /** Label shown next to the chevron. Defaults to "Back". */
  label?: string;
  /** Extra Tailwind classes forwarded to the root element. */
  className?: string;
}

/**
 * Quiet back-navigation chip.
 *
 * Behaviour:
 *   - When `window.history.length > 1` (user arrived via in-app navigation)
 *     we call `router.back()` so they return to the exact previous scroll
 *     position and query string.
 *   - Otherwise we `router.push(fallback)` — handles direct-link entry (e.g.
 *     shared URL, email link, fresh tab).
 *
 * Visual: content-width chip, h-9, muted text + ChevronLeft icon, hover
 * bg-surface-tint, focus-visible ring. No border box — matches the app's
 * "quiet chip" idiom.
 */
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

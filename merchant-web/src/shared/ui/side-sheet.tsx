"use client";

import { X } from "lucide-react";

/**
 * Left-anchored slide-over panel — full height, fixed width, scrollable body.
 * For long forms (e.g. team invite + permission matrix) where a centered modal
 * is cramped. Click-outside / the X closes it.
 */
export function SideSheet({
  title,
  onClose,
  children,
  side = "left",
  width = "w-[420px]",
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  side?: "left" | "right";
  width?: string;
}) {
  return (
    <div className="fixed inset-0 z-50 flex bg-ink/30" onClick={onClose}>
      <div
        className={`flex h-dvh ${width} max-w-full flex-col bg-white shadow-menu ${side === "right" ? "ml-auto" : ""}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex shrink-0 items-center justify-between border-b border-hairline px-lg py-md">
          <h3 className="text-title-md text-ink">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink"
          >
            <X size={18} />
          </button>
        </div>
        <div className="flex flex-1 flex-col gap-md overflow-y-auto p-lg">{children}</div>
      </div>
    </div>
  );
}

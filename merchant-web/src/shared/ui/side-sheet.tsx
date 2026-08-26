"use client";

import { useEffect, useRef } from "react";
import { X } from "@/shared/icons";

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
  const onCloseRef = useRef(onClose);
  useEffect(() => {
    onCloseRef.current = onClose;
  });

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onCloseRef.current();
    }
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, []);

  return (
    <div
      className="fixed inset-0 z-50 flex bg-scrim/60 backdrop-blur-md"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`flex h-dvh ${width} max-w-full flex-col bg-surface shadow-menu ${side === "right" ? "ml-auto" : ""}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex shrink-0 items-center justify-between border-b border-hairline px-lg py-md">
          <h3 className="text-title-md text-ink">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <X size={18} />
          </button>
        </div>
        <div className="flex flex-1 flex-col gap-md overflow-y-auto p-lg">{children}</div>
      </div>
    </div>
  );
}

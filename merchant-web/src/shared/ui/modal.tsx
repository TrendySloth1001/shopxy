"use client";

import { useEffect, useRef } from "react";
import { useTranslations } from "next-intl";
import { X } from "lucide-react";

/**
 * Centered (mobile: bottom-sheet) dialog on a scrim. The header (title + close)
 * stays fixed while the body scrolls. Escape and click-outside close it, and
 * the page behind is scroll-locked while it's open.
 */
export function Modal({
  title,
  onClose,
  children,
  wide,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  wide?: boolean;
}) {
  const t = useTranslations("common");
  // Keep the latest onClose without re-running the mount effect each render.
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
      className="fixed inset-0 z-50 flex items-end justify-center bg-scrim/30 p-lg sm:items-center"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`flex max-h-[85dvh] w-full flex-col overflow-hidden rounded-dialog bg-surface shadow-menu ${
          wide ? "max-w-content" : "max-w-form"
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between gap-md border-b border-hairline px-lg py-md">
          <h3 className="min-w-0 truncate text-title-md text-ink">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            aria-label={t("close")}
            className="-mr-xs inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <X size={18} />
          </button>
        </div>
        <div className="flex flex-col gap-md overflow-y-auto p-lg">{children}</div>
      </div>
    </div>
  );
}

export function ModalActions({
  busy,
  disabled,
  confirmLabel,
  onCancel,
  onConfirm,
  danger,
}: {
  busy: boolean;
  disabled?: boolean;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
  danger?: boolean;
}) {
  const t = useTranslations("common");
  return (
    <div className="mt-sm flex justify-end gap-md">
      <button
        type="button"
        onClick={onCancel}
        disabled={busy}
        className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink disabled:text-disabled"
      >
        {t("cancel")}
      </button>
      <button
        type="button"
        onClick={onConfirm}
        disabled={busy || disabled}
        className={`inline-flex h-10 items-center rounded-button px-lg text-label-md text-white transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:bg-disabled ${
          danger
            ? "bg-error hover:opacity-90 focus-visible:ring-error-soft"
            : "bg-brand hover:bg-brand-strong focus-visible:ring-brand-soft"
        }`}
      >
        {busy ? t("saving") : confirmLabel}
      </button>
    </div>
  );
}

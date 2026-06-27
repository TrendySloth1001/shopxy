"use client";

/** Centered (mobile: bottom-sheet) dialog on a scrim. Click-outside closes. */
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
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-scrim/30 p-lg sm:items-center"
      onClick={onClose}
    >
      <div
        className={`flex max-h-[85dvh] w-full flex-col gap-md overflow-y-auto rounded-dialog bg-surface p-lg shadow-menu ${
          wide ? "max-w-content" : "max-w-form"
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-title-md text-ink">{title}</h3>
        {children}
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
  return (
    <div className="mt-sm flex justify-end gap-md">
      <button
        type="button"
        onClick={onCancel}
        disabled={busy}
        className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink disabled:text-disabled"
      >
        Cancel
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
        {busy ? "Saving…" : confirmLabel}
      </button>
    </div>
  );
}

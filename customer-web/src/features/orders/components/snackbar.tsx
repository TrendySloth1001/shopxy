"use client";

export type SnackTone = "success" | "error" | "info";

export type SnackMessage = {
  message: string;
  tone: SnackTone;
};

export function Snackbar({ snack }: { snack: SnackMessage | null }) {
  if (!snack) return null;
  const bg =
    snack.tone === "success"
      ? "bg-success"
      : snack.tone === "error"
        ? "bg-error"
        : "bg-info";
  return (
    <div
      role="status"
      aria-live="polite"
      className={`fixed bottom-xl left-1/2 z-50 -translate-x-1/2 rounded-lg ${bg} px-lg py-sm text-label-md font-bold text-white shadow-snackbar max-w-snug text-center pointer-events-none`}
    >
      {snack.message}
    </div>
  );
}

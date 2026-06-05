import { statusLabel, statusTone, type OrderTone } from "../format";

const TONE_STYLES: Record<OrderTone, string> = {
  success: "bg-success-soft text-success",
  warning: "bg-warning-soft text-warning",
  error: "bg-error-soft text-error",
  neutral: "bg-surface-tint text-muted",
};

/** Soft-filled status pill — no border (house style). */
export function OrderStatusBadge({ status }: { status: string }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-sm py-px text-body-sm ${TONE_STYLES[statusTone(status)]}`}
    >
      {statusLabel(status)}
    </span>
  );
}

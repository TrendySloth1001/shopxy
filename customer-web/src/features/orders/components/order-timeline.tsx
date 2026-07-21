"use client";

import {
  Receipt,
  CheckCircle,
  Package,
  Truck,
  Wind,
  PackageCheck,
  XCircle,
  Ban,
  RotateCcw,
} from "@/shared/icons";
import { formatDateTime } from "@/shared/datetime";
import type { OrderEvent } from "../types";

type Stop = {
  label: string;
  Icon: React.FC<{ size?: number; className?: string }>;
  event?: OrderEvent;
  tone?: "normal" | "danger" | "warning";
};

function StopRow({
  stop,
  isFirst,
  isLast,
}: {
  stop: Stop;
  isFirst: boolean;
  isLast: boolean;
}) {
  const reached = !!stop.event;
  const tone = stop.tone ?? "normal";

  // Color based on tone and reached state
  const dotColor = !reached
    ? "border-hairline bg-canvas"
    : tone === "danger"
      ? "border-error bg-error"
      : tone === "warning"
        ? "border-warning bg-warning"
        : "border-success bg-success";

  const lineColor =
    !reached
      ? "bg-hairline"
      : tone === "danger"
        ? "bg-error"
        : tone === "warning"
          ? "bg-warning"
          : "bg-success";

  const iconColor = !reached
    ? "text-muted"
    : tone === "danger"
      ? "text-white"
      : tone === "warning"
        ? "text-white"
        : "text-white";

  const { Icon } = stop;
  const e = stop.event;

  return (
    <div className="flex items-stretch">
      {/* Rail column */}
      <div className="flex w-7 flex-col items-center">
        <div className={`w-0.5 flex-1 ${isFirst ? "bg-transparent" : lineColor}`} />
        <div
          className={`flex h-[22px] w-[22px] flex-shrink-0 items-center justify-center rounded-full border-2 ${dotColor}`}
        >
          <Icon size={11} className={iconColor} />
        </div>
        <div className={`w-0.5 flex-1 ${isLast ? "bg-transparent" : lineColor}`} />
      </div>

      {/* Content */}
      <div className="ml-md flex-1 pb-sm pt-xs">
        <p
          className={`text-body-sm font-semibold ${reached ? "text-ink font-extrabold" : "text-muted"}`}
        >
          {stop.label}
        </p>
        {e && (
          <div className="mt-xxs space-y-xxs">
            <p className="text-caption text-muted">{formatDateTime(e.occurredAt)}</p>
            {(e.courier ?? e.awb) && (
              <p className="text-caption font-bold text-brand-strong">
                {[e.courier, e.awb ? `AWB ${e.awb}` : null].filter(Boolean).join(" · ")}
              </p>
            )}
            {e.eta && (
              <p className="text-caption font-bold text-brand-strong">
                ETA {new Date(e.eta).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}
              </p>
            )}
            {e.note && <p className="text-caption leading-[1.3] text-muted">{e.note}</p>}
          </div>
        )}
      </div>
    </div>
  );
}

export function OrderTimeline({
  events,
  status,
}: {
  events: OrderEvent[];
  status: string;
}) {
  if (events.length === 0) return null;

  // Deduplicate: keep latest event per type
  const byType = new Map<string, OrderEvent>();
  for (const e of events) {
    const prev = byType.get(e.type);
    if (!prev || new Date(e.occurredAt) > new Date(prev.occurredAt)) {
      byType.set(e.type, e);
    }
  }

  const terminated = status === "REJECTED" || status === "CANCELLED";
  const returned = byType.has("RETURNED");

  const stops: Stop[] = [
    { label: "Order placed", Icon: Receipt, event: byType.get("CREATED") },
  ];

  if (terminated) {
    stops.push({
      label: status === "REJECTED" ? "Declined by seller" : "Cancelled",
      Icon: status === "REJECTED" ? XCircle : Ban,
      event: byType.get(status),
      tone: "danger",
    });
  } else {
    stops.push(
      { label: "Confirmed", Icon: CheckCircle, event: byType.get("CONFIRMED") },
      { label: "Packed", Icon: Package, event: byType.get("PACKED") },
      { label: "Shipped", Icon: Truck, event: byType.get("SHIPPED") },
      { label: "Out for delivery", Icon: Wind, event: byType.get("OUT_FOR_DELIVERY") },
      { label: "Delivered", Icon: PackageCheck, event: byType.get("DELIVERED") },
    );
  }

  if (returned) {
    stops.push({
      label: "Returned",
      Icon: RotateCcw,
      event: byType.get("RETURNED"),
      tone: "warning",
    });
  }

  return (
    <div className="px-md pb-sm pt-md">
      <p className="mb-sm text-caption font-extrabold tracking-[0.4px] text-muted uppercase">
        Tracking
      </p>
      {stops.map((stop, i) => (
        <StopRow
          key={stop.label}
          stop={stop}
          isFirst={i === 0}
          isLast={i === stops.length - 1}
        />
      ))}
    </div>
  );
}

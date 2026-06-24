"use client";

import {
  RotateCcw,
  CheckCircle,
  XCircle,
  Package,
  PackageCheck,
  BadgeIndianRupee,
} from "lucide-react";
import { formatDateTime } from "@/shared/datetime";
import type { ReturnEvent } from "../types";

type Stop = {
  label: string;
  Icon: React.FC<{ size?: number; className?: string }>;
  event?: ReturnEvent;
  tone?: "normal" | "danger" | "success";
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

  const dotClass = !reached
    ? "border-hairline bg-canvas"
    : tone === "danger"
      ? "border-error bg-error"
      : tone === "success"
        ? "border-success bg-success"
        : "border-brand bg-brand";

  const lineClass =
    !reached
      ? "bg-hairline"
      : tone === "danger"
        ? "bg-error"
        : tone === "success"
          ? "bg-success"
          : "bg-brand";

  const { Icon } = stop;
  const e = stop.event;

  return (
    <div className="flex items-stretch">
      <div className="flex w-7 flex-col items-center">
        <div className={`w-0.5 flex-1 ${isFirst ? "bg-transparent" : lineClass}`} />
        <div
          className={`flex h-[22px] w-[22px] flex-shrink-0 items-center justify-center rounded-full border-2 ${dotClass}`}
        >
          <Icon size={11} className={!reached ? "text-muted" : "text-white"} />
        </div>
        <div className={`w-0.5 flex-1 ${isLast ? "bg-transparent" : lineClass}`} />
      </div>
      <div className="ml-md flex-1 pb-sm pt-xs">
        <p
          className={`text-body-sm ${reached ? "font-extrabold text-ink" : "font-semibold text-muted"}`}
        >
          {stop.label}
        </p>
        {e && (
          <div className="mt-[2px] space-y-[2px]">
            <p className="text-[11px] text-muted">{formatDateTime(e.occurredAt)}</p>
            {e.note && <p className="text-[11px] leading-[1.3] text-muted">{e.note}</p>}
          </div>
        )}
      </div>
    </div>
  );
}

export function ReturnTimeline({
  events,
  status,
}: {
  events: ReturnEvent[];
  status: string;
}) {
  const byType = new Map<string, ReturnEvent>();
  for (const e of events) {
    const prev = byType.get(e.type);
    if (!prev || new Date(e.occurredAt) > new Date(prev.occurredAt)) {
      byType.set(e.type, e);
    }
  }

  const stops: Stop[] = [
    { label: "Return requested", Icon: RotateCcw, event: byType.get("REQUESTED") },
  ];

  if (status === "CANCELLED") {
    stops.push({
      label: "Cancelled",
      Icon: XCircle,
      event: byType.get("CANCELLED"),
      tone: "danger",
    });
  } else if (status === "REJECTED") {
    stops.push({
      label: "Rejected",
      Icon: XCircle,
      event: byType.get("REJECTED"),
      tone: "danger",
    });
  } else {
    stops.push(
      { label: "Approved", Icon: CheckCircle, event: byType.get("APPROVED") },
      { label: "Item picked up", Icon: Package, event: byType.get("PICKED_UP") },
      { label: "Item received", Icon: PackageCheck, event: byType.get("RECEIVED") },
      {
        label: "Refunded",
        Icon: BadgeIndianRupee,
        event: byType.get("REFUNDED"),
        tone: "success",
      },
    );
  }

  return (
    <div>
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

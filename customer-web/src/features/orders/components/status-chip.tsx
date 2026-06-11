"use client";

import {
  CheckCircle,
  XCircle,
  Clock,
  Ban,
  HelpCircle,
  Hourglass,
} from "lucide-react";
import type { ShopOrderPreview } from "../types";
import { isChildConfirmed, isChildRejected, isChildCancelled, isChildPending } from "../types";

// ─── Shop-order (per-vendor slice) chip ──────────────────────────────────────

type SliceStatus = "PENDING" | "CONFIRMED" | "REJECTED" | "CANCELLED" | string;

function sliceVisual(status: SliceStatus): {
  label: string;
  colorClass: string;
  bgClass: string;
  Icon: React.FC<{ className?: string; size?: number }>;
} {
  switch (status) {
    case "CONFIRMED":
      return {
        label: "CONFIRMED",
        colorClass: "text-success",
        bgClass: "bg-success-soft",
        Icon: CheckCircle,
      };
    case "REJECTED":
      return {
        label: "DECLINED",
        colorClass: "text-error",
        bgClass: "bg-error-soft",
        Icon: XCircle,
      };
    case "CANCELLED":
      return {
        label: "CANCELLED",
        colorClass: "text-muted",
        bgClass: "bg-surface-tint",
        Icon: Ban,
      };
    default:
      return {
        label: "PENDING",
        colorClass: "text-warning",
        bgClass: "bg-warning-soft",
        Icon: Clock,
      };
  }
}

export function ShopOrderStatusChip({ status }: { status: string }) {
  const { label, colorClass, bgClass } = sliceVisual(status);
  return (
    <span
      className={`inline-flex items-center gap-xs rounded-full px-sm py-[3px] text-[10px] font-extrabold tracking-[0.4px] ${colorClass} ${bgClass}`}
    >
      {label}
    </span>
  );
}

// ─── Aggregate parent order chip ─────────────────────────────────────────────

function aggregateVisual(order: { shopOrders: ShopOrderPreview[] }): {
  label: string;
  colorClass: string;
  bgClass: string;
  Icon: React.FC<{ className?: string; size?: number }>;
} {
  const children = order.shopOrders;
  if (children.length === 0)
    return { label: "PENDING", colorClass: "text-warning", bgClass: "bg-warning-soft", Icon: Clock };

  const confirmed = children.filter(isChildConfirmed).length;
  const pending = children.filter(isChildPending).length;
  const rejected = children.filter(isChildRejected).length;
  const cancelled = children.filter(isChildCancelled).length;
  const total = children.length;

  if (confirmed === total)
    return { label: "CONFIRMED", colorClass: "text-success", bgClass: "bg-success-soft", Icon: CheckCircle };
  if (cancelled === total)
    return { label: "CANCELLED", colorClass: "text-muted", bgClass: "bg-surface-tint", Icon: Ban };
  if (rejected === total)
    return { label: "DECLINED", colorClass: "text-error", bgClass: "bg-error-soft", Icon: XCircle };
  if (pending === total)
    return { label: "PENDING", colorClass: "text-warning", bgClass: "bg-warning-soft", Icon: Clock };

  return {
    label: `${confirmed}/${total} CONFIRMED`,
    colorClass: "text-warning",
    bgClass: "bg-warning-soft",
    Icon: Hourglass,
  };
}

export function AggregateStatusChip({ order }: { order: { shopOrders: ShopOrderPreview[] } }) {
  const { label, colorClass, bgClass, Icon } = aggregateVisual(order);
  return (
    <span
      className={`inline-flex items-center gap-xs rounded-full px-sm py-[3px] text-[10px] font-extrabold tracking-[0.4px] ${colorClass} ${bgClass}`}
    >
      <Icon size={10} />
      {label}
    </span>
  );
}

// ─── Aggregate status headline (for detail page order summary) ────────────────

export function aggregateStatusHeadline(order: { shopOrders: ShopOrderPreview[] }): {
  headline: string;
  subtext?: string;
  colorClass: string;
  Icon: React.FC<{ className?: string; size?: number }>;
} {
  const children = order.shopOrders;
  if (children.length === 0) {
    return { headline: "No sellers", colorClass: "text-muted", Icon: HelpCircle };
  }
  const confirmed = children.filter(isChildConfirmed).length;
  const pending = children.filter(isChildPending).length;
  const rejected = children.filter(isChildRejected).length;
  const cancelled = children.filter(isChildCancelled).length;
  const total = children.length;

  if (confirmed === total)
    return {
      headline: total === 1 ? "Confirmed" : "All sellers confirmed",
      colorClass: "text-success",
      Icon: CheckCircle,
    };
  if (cancelled === total)
    return {
      headline: "Cancelled",
      subtext: "No charges apply",
      colorClass: "text-muted",
      Icon: Ban,
    };
  if (rejected === total)
    return {
      headline: total === 1 ? "Declined" : "All sellers declined",
      colorClass: "text-error",
      Icon: XCircle,
    };
  if (pending === total)
    return {
      headline: total === 1 ? "Waiting on seller" : `Waiting on ${total} sellers`,
      colorClass: "text-warning",
      Icon: Clock,
    };

  return {
    headline: `${confirmed} of ${total} confirmed`,
    colorClass: "text-warning",
    Icon: Hourglass,
  };
}

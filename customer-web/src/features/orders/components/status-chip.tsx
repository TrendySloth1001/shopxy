"use client";

import {
  CheckCircle,
  XCircle,
  Clock,
  Ban,
  HelpCircle,
  Hourglass,
} from "@/shared/icons";
import type { ShopOrderPreview } from "../types";
import { isChildConfirmed, isChildRejected, isChildCancelled, isChildPending } from "../types";

type StatusKind = "PENDING" | "CONFIRMED" | "CANCELLED" | "REJECTED" | string;

interface StatusVisual {
  label: string;
  colorClass: string;
  bgClass: string;
  Icon: React.FC<{ className?: string; size?: number }>;
}

export function statusVisual(status: StatusKind): StatusVisual {
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

export function ChipStatus({
  status,
  showIcon = false,
}: {
  status: string;
  showIcon?: boolean;
}) {
  const { label, colorClass, bgClass, Icon } = statusVisual(status);
  return (
    <span
      className={`inline-flex items-center gap-xs rounded-full px-sm py-[3px] text-micro font-extrabold tracking-[0.4px] ${colorClass} ${bgClass}`}
    >
      {showIcon ? <Icon size={10} aria-hidden /> : null}
      {label}
    </span>
  );
}

export function ShopOrderStatusChip({ status }: { status: string }) {
  return <ChipStatus status={status} />;
}

function aggregateLabel(order: { shopOrders: ShopOrderPreview[] }): {
  label: string;
  statusKey: string;
} {
  const children = order.shopOrders;
  if (children.length === 0) return { label: "PENDING", statusKey: "PENDING" };

  const confirmed = children.filter(isChildConfirmed).length;
  const pending = children.filter(isChildPending).length;
  const rejected = children.filter(isChildRejected).length;
  const cancelled = children.filter(isChildCancelled).length;
  const total = children.length;

  if (confirmed === total) return { label: "CONFIRMED", statusKey: "CONFIRMED" };
  if (cancelled === total) return { label: "CANCELLED", statusKey: "CANCELLED" };
  if (rejected === total) return { label: "DECLINED", statusKey: "REJECTED" };
  if (pending === total) return { label: "PENDING", statusKey: "PENDING" };

  return { label: `${confirmed}/${total} CONFIRMED`, statusKey: "PENDING" };
}

export function AggregateStatusChip({ order }: { order: { shopOrders: ShopOrderPreview[] } }) {
  const { label, statusKey } = aggregateLabel(order);
  const { colorClass, bgClass, Icon } = statusVisual(statusKey);
  return (
    <span
      className={`inline-flex items-center gap-xs rounded-full px-sm py-[3px] text-micro font-extrabold tracking-[0.4px] ${colorClass} ${bgClass}`}
    >
      <Icon size={10} aria-hidden />
      {label}
    </span>
  );
}

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

  if (confirmed === total) {
    const v = statusVisual("CONFIRMED");
    return {
      headline: total === 1 ? "Confirmed" : "All sellers confirmed",
      colorClass: v.colorClass,
      Icon: v.Icon,
    };
  }
  if (cancelled === total) {
    const v = statusVisual("CANCELLED");
    return {
      headline: "Cancelled",
      subtext: "No charges apply",
      colorClass: v.colorClass,
      Icon: v.Icon,
    };
  }
  if (rejected === total) {
    const v = statusVisual("REJECTED");
    return {
      headline: total === 1 ? "Declined" : "All sellers declined",
      colorClass: v.colorClass,
      Icon: v.Icon,
    };
  }
  if (pending === total) {
    const v = statusVisual("PENDING");
    return {
      headline: total === 1 ? "Waiting on seller" : `Waiting on ${total} sellers`,
      colorClass: v.colorClass,
      Icon: v.Icon,
    };
  }

  return {
    headline: `${confirmed} of ${total} confirmed`,
    colorClass: statusVisual("PENDING").colorClass,
    Icon: Hourglass,
  };
}

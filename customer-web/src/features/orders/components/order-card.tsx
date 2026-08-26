"use client";

import Link from "next/link";
import { ChevronRight, AlertCircle } from "@/shared/icons";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";
import { AggregateStatusChip } from "./status-chip";
import type { CustomerOrder } from "../types";
import { orderNeedsOnlinePayment } from "../types";

function sellerLine(order: CustomerOrder): string {
  const names = order.shopOrders.map(
    (s) => s.shop?.shopName ?? s.shop?.name ?? "Seller",
  );
  if (names.length === 0) return "No sellers";
  if (names.length === 1) return `Sold by ${names[0]}`;
  if (names.length === 2) return `Sold by ${names[0]} & ${names[1]}`;
  return `Sold by ${names[0]} & ${names.length - 1} others`;
}

function totalItemCount(order: CustomerOrder): number {
  return order.shopOrders.reduce((sum, s) => sum + (s._count?.items ?? 0), 0);
}

export function OrderCard({ order }: { order: CustomerOrder }) {
  const needsPayment = orderNeedsOnlinePayment(order);
  const count = totalItemCount(order);

  return (
    <Link
      href={`/orders/${order.id}`}
      className="block rounded-lg border border-hairline bg-white p-md transition-all duration-200 hover:bg-surface-tint/40 hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
    >
      <div className="flex items-start justify-between gap-sm">
        <span className="text-title-sm font-extrabold text-ink">Order #{order.id}</span>
        <AggregateStatusChip order={order} />
      </div>

      <p className="mt-xs text-body-sm font-semibold text-muted truncate">
        {sellerLine(order)}
      </p>
      <p className="mt-xxs text-body-sm text-muted">
        {count > 0 ? `${count} ${count === 1 ? "item" : "items"} · ` : ""}
        {formatDateTime(order.createdAt)}
      </p>

      <div className="my-sm h-px bg-hairline" />

      <div className="flex items-center justify-between">
        <div className="flex items-center gap-xs">
          <span className="text-body-sm font-bold text-muted">Total</span>
          <span className="text-body-md font-extrabold text-ink">
            {formatINR(order.estimatedTotal, { decimals: 2 })}
          </span>
        </div>
        {needsPayment ? (
          <span className="inline-flex items-center gap-xs rounded-full bg-warning-soft px-sm py-[3px] text-nano font-extrabold tracking-[0.4px] text-warning">
            <AlertCircle size={9} />
            PAYMENT DUE
          </span>
        ) : (
          <ChevronRight size={16} className="text-subtle" />
        )}
      </div>
    </Link>
  );
}

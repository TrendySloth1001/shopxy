import type { OrderItem, OrderDetail } from "./schema";

/** Money + qty formatting is shared with the products feature. */
export { money, qty } from "@/features/products/format";
export { unitLabel } from "@/features/products/units";

export type OrderTone = "success" | "warning" | "error" | "neutral";

/** Status → badge tone, matching the Flutter inbox/detail mapping. */
export function statusTone(status: string): OrderTone {
  switch (status) {
    case "CONFIRMED":
      return "success";
    case "REJECTED":
      return "error";
    case "CANCELLED":
      return "neutral";
    default:
      return "warning"; // PENDING / PROCESSING
  }
}

/** Human label for a status (Title Case). */
export function statusLabel(status: string): string {
  if (!status) return "";
  return status.charAt(0) + status.slice(1).toLowerCase();
}

/** True if we can fulfil this line right now. Unknown stock → conservative no. */
export function itemStockOk(item: OrderItem): boolean {
  const active = item.product?.isActive ?? true;
  const stock = item.product?.stockQuantity;
  return active && stock != null && stock >= item.quantity;
}

/** Amount we're short by for this line (0 when fine; full qty when unknown). */
export function itemShortfall(item: OrderItem): number {
  const stock = item.product?.stockQuantity ?? 0;
  return stock >= item.quantity ? 0 : item.quantity - stock;
}

/** Any line that can't be fully fulfilled right now. */
export function hasStockShortfall(order: OrderDetail): boolean {
  return order.items.some((i) => !itemStockOk(i));
}

/** How many lines are short — drives the shortfall banner headline. */
export function shortItemCount(order: OrderDetail): number {
  return order.items.filter((i) => !itemStockOk(i)).length;
}

/** Subtotal from line totals (reflects the current items, not the snapshot). */
export function subtotal(order: OrderDetail): number {
  return order.items.reduce((acc, i) => acc + i.total, 0);
}

const dateTimeFmt = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

/** "5 Jun 2026, 4:30 pm" */
export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : dateTimeFmt.format(d);
}

/** "just now" / "5 min ago" / "3 hrs ago" / "2 days ago" / "5 Jun". */
export function relativeTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const diffMs = Date.now() - d.getTime();
  const min = Math.floor(diffMs / 60000);
  if (min < 1) return "just now";
  if (min < 60) return `${min} min ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr} hr${hr === 1 ? "" : "s"} ago`;
  const day = Math.floor(hr / 24);
  if (day < 7) return `${day} day${day === 1 ? "" : "s"} ago`;
  return new Intl.DateTimeFormat("en-IN", { day: "numeric", month: "short" }).format(d);
}

import type { OrderItem, OrderDetail } from "./schema";

export { money, qty } from "@/features/products/format";
export { unitLabel } from "@/features/products/units";

export type OrderTone = "success" | "warning" | "error" | "neutral";

export function statusTone(status: string): OrderTone {
  switch (status) {
    case "CONFIRMED":
      return "success";
    case "REJECTED":
      return "error";
    case "CANCELLED":
      return "neutral";
    default:
      return "warning";
  }
}

export function statusLabel(status: string): string {
  if (!status) return "";
  return status.charAt(0) + status.slice(1).toLowerCase();
}

export function itemStockOk(item: OrderItem): boolean {
  const active = item.product?.isActive ?? true;
  const stock = item.product?.stockQuantity;
  return active && stock != null && stock >= item.quantity;
}

export function itemShortfall(item: OrderItem): number {
  const stock = item.product?.stockQuantity ?? 0;
  return stock >= item.quantity ? 0 : item.quantity - stock;
}

export function hasStockShortfall(order: OrderDetail): boolean {
  return order.items.some((i) => !itemStockOk(i));
}

export function shortItemCount(order: OrderDetail): number {
  return order.items.filter((i) => !itemStockOk(i)).length;
}

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

export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : dateTimeFmt.format(d);
}

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

import type {
  ConfirmResult,
  OrderDetail,
  OrderList,
} from "./schema";

export class OrderConfirmError extends Error {
  readonly code: string;
  readonly productId?: string;
  readonly available?: number;
  readonly requested?: number;

  constructor(opts: {
    code: string;
    message: string;
    productId?: string;
    available?: number;
    requested?: number;
  }) {
    super(opts.message);
    this.name = "OrderConfirmError";
    this.code = opts.code;
    this.productId = opts.productId;
    this.available = opts.available;
    this.requested = opts.requested;
  }
}

async function jsonOrThrow<T>(res: Response, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
    }
    throw new Error(message);
  }
  return (await res.json()) as T;
}

export function listOrders(query: Record<string, string>): Promise<OrderList> {
  const qs = new URLSearchParams(query).toString();
  return fetch(`/api/orders${qs ? `?${qs}` : ""}`, { cache: "no-store" }).then(
    (r) => jsonOrThrow<OrderList>(r, "Could not load orders."),
  );
}

export function getOrder(id: string): Promise<OrderDetail> {
  return fetch(`/api/orders/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow<OrderDetail>(r, "Could not load the order."),
  );
}

export function pendingOrderCount(): Promise<number> {
  return fetch("/api/orders/pending-count", { cache: "no-store" })
    .then((r) => (r.ok ? (r.json() as Promise<{ count: number }>) : { count: 0 }))
    .then((b) => b.count ?? 0)
    .catch(() => 0);
}

export async function confirmOrder(
  id: string,
  note?: string,
): Promise<ConfirmResult> {
  const res = await fetch(`/api/orders/${id}/confirm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(note ? { note } : {}),
  });
  if (res.ok) return (await res.json()) as ConfirmResult;

  let body: {
    error?: string;
    productId?: string;
    available?: number;
    requested?: number;
  } = {};
  try {
    body = (await res.json()) as typeof body;
  } catch {
  }
  const code = body.error ?? "CONFIRM_FAILED";
  throw new OrderConfirmError({
    code,
    message: confirmMessage(code),
    productId: body.productId,
    available: body.available,
    requested: body.requested,
  });
}

export const SHIPPING_MILESTONES = [
  "PACKED",
  "SHIPPED",
  "OUT_FOR_DELIVERY",
  "DELIVERED",
] as const;
export type ShippingMilestone = (typeof SHIPPING_MILESTONES)[number];

export const SHIPPING_MILESTONE_LABELS: Record<ShippingMilestone, string> = {
  PACKED: "Packed",
  SHIPPED: "Shipped",
  OUT_FOR_DELIVERY: "Out for delivery",
  DELIVERED: "Delivered",
};

export async function addShippingEvent(
  id: string,
  input: { type: ShippingMilestone; courier?: string; awb?: string; eta?: string; note?: string },
): Promise<void> {
  const res = await fetch(`/api/orders/${id}/events`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, "Could not update shipping.");
  }
}

export async function rejectOrder(id: string, note?: string): Promise<void> {
  const res = await fetch(`/api/orders/${id}/reject`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(note ? { note } : {}),
  });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, "Could not decline the order.");
  }
}

function confirmMessage(code: string): string {
  switch (code) {
    case "INSUFFICIENT_STOCK":
      return "Not enough stock to fulfil this order.";
    case "NOT_FOUND":
      return "Order not found.";
    case "NOT_PENDING":
      return "This order is no longer pending.";
    case "NO_ITEMS":
      return "This order has no items.";
    default:
      return code || "Could not confirm the order.";
  }
}

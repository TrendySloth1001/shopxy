import {
  ordersPageSchema,
  customerOrderDetailSchema,
  reorderResultSchema,
  paySessionSchema,
  type OrdersPage,
  type CustomerOrderDetail,
  type ReorderResult,
} from "./types";
import type { PaySession } from "@/shared/razorpay";

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchOrders(opts?: {
  page?: number;
  limit?: number;
}): Promise<OrdersPage> {
  const qs = new URLSearchParams({
    page: String(opts?.page ?? 1),
    limit: String(opts?.limit ?? 20),
  });
  const res = await fetch(`/api/me/orders?${qs}`, { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => ordersPageSchema.parse(raw),
    "Could not load orders.",
  );
}

export async function fetchOrderDetail(id: string): Promise<CustomerOrderDetail> {
  const res = await fetch(`/api/me/orders/${id}`, { cache: "no-store" });
  return jsonOrThrow(
    res,
    (raw) => customerOrderDetailSchema.parse(raw),
    "Could not load order.",
  );
}

export async function cancelShopOrder(parentId: string, childId: string): Promise<void> {
  const res = await fetch(`/api/me/orders/${parentId}/shops/${childId}/cancel`, {
    method: "POST",
  });
  if (!res.ok) {
    let message = "Could not cancel order.";
    let code: string | undefined;
    try {
      const b = (await res.json()) as { error?: string; code?: string };
      if (b?.error) message = b.error;
      if (b?.code) code = b.code;
    } catch {
    }
    const err = new Error(message) as Error & { code?: string };
    err.code = code;
    throw err;
  }
}

export async function reorderOrder(id: string): Promise<ReorderResult> {
  const res = await fetch(`/api/me/orders/${id}/reorder`, { method: "POST" });
  return jsonOrThrow(
    res,
    (raw) => reorderResultSchema.parse(raw),
    "Could not reorder.",
  );
}

export async function payForOrder(id: string): Promise<PaySession> {
  const res = await fetch(`/api/me/orders/${id}/pay`, { method: "POST" });
  return jsonOrThrow(
    res,
    (raw) => paySessionSchema.parse(raw),
    "Could not start payment.",
  );
}

export async function syncOrderPayment(id: string): Promise<string | null> {
  const res = await fetch(`/api/me/orders/${id}/payment/sync`, { method: "POST" });
  if (!res.ok) return null;
  const body = (await res.json().catch(() => null)) as { paymentStatus?: string } | null;
  return body?.paymentStatus ?? null;
}

export function invoicePdfUrl(parentId: string, childId: string): string {
  return `/api/me/orders/${parentId}/shops/${childId}/invoice.pdf`;
}

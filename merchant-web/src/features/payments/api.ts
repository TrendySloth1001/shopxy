import { paymentListSchema, paymentSchema, type Payment } from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

async function okOrThrow(res: Response, fallback: string): Promise<void> {
  if (res.ok || res.status === 204) return;
  await jsonOrThrow(res, () => null, fallback);
}

export function listPayments(opts: {
  invoiceId?: number;
  partyId?: number;
  vendorId?: number;
}): Promise<Payment[]> {
  const qs = new URLSearchParams({ limit: "100" });
  if (opts.invoiceId != null) qs.set("invoiceId", String(opts.invoiceId));
  if (opts.partyId != null) qs.set("partyId", String(opts.partyId));
  if (opts.vendorId != null) qs.set("vendorId", String(opts.vendorId));
  return fetch(`/api/payments?${qs.toString()}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => paymentListSchema.parse(raw).data, "Could not load payments."),
  );
}

export type PaymentWrite = {
  type: "RECEIPT" | "PAYMENT";
  amount: number;
  mode: string;
  modeReference?: string;
  paymentDate?: string;
  partyId?: number;
  vendorId?: number;
  invoiceId?: number;
  note?: string;
};

export function createPayment(input: PaymentWrite): Promise<Payment> {
  return fetch("/api/payments", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => paymentSchema.parse(raw), "Could not record the payment."));
}

export async function voidPayment(id: number, reason?: string): Promise<void> {
  const qs = reason ? `?reason=${encodeURIComponent(reason)}` : "";
  const res = await fetch(`/api/payments/${id}${qs}`, { method: "DELETE" });
  await okOrThrow(res, "Could not void the payment.");
}

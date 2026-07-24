import { z } from "zod";

/**
 * Client shapes + fetchers for the dashboard KPI drawers' receivables /
 * payables drill-downs, mirroring the backend `GET /dashboard/receivables`
 * and `/dashboard/payables` (`dashboard.service.assembleBreakdown`). Each
 * lists debtors/creditors (biggest balance first) with the confirmed
 * documents behind the balance. Validated at the BFF boundary.
 */

const money = z.coerce.number().default(0);

const breakdownInvoiceSchema = z.object({
  id: z.coerce.string(),
  invoiceNo: z.string(),
  documentType: z.string().default("TAX_INVOICE"),
  invoiceDate: z.string(),
  total: money,
});
export type BreakdownInvoice = z.infer<typeof breakdownInvoiceSchema>;

const counterpartySchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  billed: money,
  // Named `received` on the receivables side, `paid` on the payables side.
  received: money.optional(),
  paid: money.optional(),
  outstanding: money,
  invoices: z
    .array(breakdownInvoiceSchema)
    .nullish()
    .transform((v) => v ?? []),
});
export type Counterparty = z.infer<typeof counterpartySchema>;

export const breakdownSchema = z.object({
  outstanding: money,
  count: z.number().default(0),
  parties: z
    .array(counterpartySchema)
    .nullish()
    .transform((v) => v ?? []),
});
export type Breakdown = z.infer<typeof breakdownSchema>;

/** The amount already settled against a counterparty, whichever side. */
export function settled(c: Counterparty): number {
  return c.received ?? c.paid ?? 0;
}

async function getBreakdown(path: string, fallback: string): Promise<Breakdown> {
  const res = await fetch(path, { cache: "no-store" });
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
  return breakdownSchema.parse(await res.json());
}

export function getReceivables(): Promise<Breakdown> {
  return getBreakdown("/api/dashboard/receivables", "Could not load receivables.");
}

export function getPayables(): Promise<Breakdown> {
  return getBreakdown("/api/dashboard/payables", "Could not load payables.");
}

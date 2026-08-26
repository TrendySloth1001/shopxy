import { z } from "zod";

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

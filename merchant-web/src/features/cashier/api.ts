import { z } from "zod";

/// Cashier control-center client API — zod-validated reads against the BFF
/// (/api/cashier/*), mirroring the backend cashier.service shapes.

export const shiftSchema = z.object({
  id: z.coerce.string(),
  status: z.string(),
  openingFloat: z.number(),
  openedById: z.coerce.string(),
  openedByName: z.string().nullable(),
  openedByEmail: z.string().nullable(),
  openedAt: z.string(),
  closedAt: z.string().nullable(),
  closingCounted: z.number().nullable(),
  expectedCash: z.number().nullable(),
  variance: z.number().nullable(),
  closingNote: z.string().nullable(),
});
export type Shift = z.infer<typeof shiftSchema>;

export const reportSchema = z.object({
  shift: shiftSchema,
  sales: z.object({ count: z.number(), gross: z.number() }),
  tenders: z.array(z.object({ mode: z.string(), amount: z.number(), count: z.number() })),
  cash: z.object({
    openingFloat: z.number(),
    cashSales: z.number(),
    payIns: z.number(),
    payOuts: z.number(),
    drops: z.number(),
    refunds: z.number(),
    expected: z.number(),
    counted: z.number().nullable(),
    variance: z.number().nullable(),
  }),
  gst: z.object({
    taxable: z.number(),
    cgst: z.number(),
    sgst: z.number(),
    igst: z.number(),
    cess: z.number(),
    total: z.number(),
  }),
  gstByRate: z.array(z.object({ rate: z.number(), taxable: z.number(), tax: z.number() })),
  returns: z.object({ count: z.number(), amount: z.number() }),
  movements: z.array(
    z.object({
      id: z.coerce.string(),
      type: z.string(),
      amount: z.number(),
      reason: z.string().nullable(),
      createdAt: z.string(),
    }),
  ),
});
export type ShiftReport = z.infer<typeof reportSchema>;

const currentSchema = z.object({
  shift: shiftSchema.nullable(),
  report: reportSchema.nullable(),
});

export const returnableSchema = z.object({
  invoiceId: z.coerce.string(),
  invoiceNo: z.string(),
  invoiceDate: z.string(),
  total: z.number(),
  customerName: z.string().nullable(),
  lines: z.array(
    z.object({
      productId: z.coerce.string(),
      name: z.string(),
      sku: z.string(),
      unitPrice: z.number(),
      taxPercent: z.number(),
      soldQty: z.number(),
      returnedQty: z.number(),
      returnableQty: z.number(),
    }),
  ),
});
export type Returnable = z.infer<typeof returnableSchema>;

export const returnResultSchema = z.object({
  creditNoteId: z.coerce.string(),
  creditNoteNo: z.string(),
  refundAmount: z.number(),
  refundMode: z.string(),
  cashDrawerAdjusted: z.boolean(),
});
export type ReturnResult = z.infer<typeof returnResultSchema>;

export const shiftSummarySchema = z.object({
  id: z.coerce.string(),
  status: z.string(),
  openedById: z.coerce.string(),
  openedByName: z.string().nullable(),
  openedByEmail: z.string().nullable(),
  openedAt: z.string(),
  closedAt: z.string().nullable(),
  openingFloat: z.number(),
  expectedCash: z.number().nullable(),
  closingCounted: z.number().nullable(),
  variance: z.number().nullable(),
});
export type ShiftSummary = z.infer<typeof shiftSummarySchema>;

async function jsonOrThrow(res: Response): Promise<unknown> {
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const body = data as { error?: string; code?: string } | null;
    throw Object.assign(new Error(body?.error ?? "Request failed."), { code: body?.code });
  }
  return data;
}

/** True when an error from this module is "needs a manager to authorise". */
export function isOverrideRequired(e: unknown): boolean {
  return typeof e === "object" && e !== null && (e as { code?: string }).code === "OVERRIDE_REQUIRED";
}

export const overrideGrantSchema = z.object({ token: z.string(), authorizerName: z.string() });
export type OverrideGrant = z.infer<typeof overrideGrantSchema>;

/** Manager authorises a privileged till action with their credentials. */
export async function authorizeOverride(email: string, password: string): Promise<OverrideGrant> {
  const res = await fetch("/api/cashier/authorize", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  return overrideGrantSchema.parse(await jsonOrThrow(res));
}

export async function fetchCurrent(): Promise<{ shift: Shift | null; report: ShiftReport | null }> {
  const res = await fetch("/api/cashier/current", { cache: "no-store" });
  return currentSchema.parse(await jsonOrThrow(res));
}

export async function openShift(openingFloat: number): Promise<Shift> {
  const res = await fetch("/api/cashier/shift/open", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ openingFloat }),
  });
  return shiftSchema.parse(await jsonOrThrow(res));
}

export async function addCashMovement(input: {
  type: "PAY_IN" | "PAY_OUT" | "DROP";
  amount: number;
  reason?: string;
}): Promise<ShiftReport> {
  const res = await fetch("/api/cashier/cash-movement", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  return reportSchema.parse(await jsonOrThrow(res));
}

export async function closeShift(input: { countedCash: number; note?: string }): Promise<ShiftReport> {
  const res = await fetch("/api/cashier/shift/close", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  return reportSchema.parse(await jsonOrThrow(res));
}

export async function listShifts(): Promise<ShiftSummary[]> {
  const res = await fetch("/api/cashier/shifts", { cache: "no-store" });
  return shiftSummarySchema.array().parse(await jsonOrThrow(res));
}

export async function fetchShiftReport(shiftId: string): Promise<ShiftReport> {
  const res = await fetch(`/api/cashier/shifts/${shiftId}/report`, { cache: "no-store" });
  return reportSchema.parse(await jsonOrThrow(res));
}

export async function fetchReturnable(invoiceId: string): Promise<Returnable> {
  const res = await fetch(`/api/cashier/returnable/${invoiceId}`, { cache: "no-store" });
  return returnableSchema.parse(await jsonOrThrow(res));
}

export async function processReturn(input: {
  originalInvoiceId: string;
  refundMode: "CASH" | "UPI" | "CARD" | "OTHER";
  lines: Array<{ productId: string; quantity: number }>;
  /** Manager-authorisation grant when the cashier lacks the override right. */
  override?: string;
}): Promise<ReturnResult> {
  const res = await fetch("/api/cashier/return", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  return returnResultSchema.parse(await jsonOrThrow(res));
}

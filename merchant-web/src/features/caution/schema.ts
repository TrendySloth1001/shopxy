import { z } from "zod";

/**
 * Caution-deposit shapes, mirroring the backend `caution` module mounted under
 * `/parties/:id/caution*` and the shop-wide inbox at `/caution-requests`. All
 * amounts are rupees (Decimal serialised as numbers).
 */

export const CAUTION_MODES = ["CASH", "UPI", "NEFT", "RTGS", "CHEQUE", "CARD", "OTHER"] as const;
export type CautionMode = (typeof CAUTION_MODES)[number];

export const GST_TREATMENTS = ["NONE", "SUPPLY"] as const;
export type GstTreatment = (typeof GST_TREATMENTS)[number];

/** DEPOSIT/REFUND/ADJUSTMENT/FORFEIT — how each renders in the history list. */
export const CAUTION_TXN_META: Record<
  string,
  { label: string; sign: "+" | "−"; tone: "in" | "out" }
> = {
  DEPOSIT: { label: "Deposit", sign: "+", tone: "in" },
  REFUND: { label: "Refund", sign: "−", tone: "out" },
  ADJUSTMENT: { label: "Set-off", sign: "−", tone: "out" },
  FORFEIT: { label: "Forfeited", sign: "−", tone: "out" },
};

export const cautionTxnSchema = z
  .object({
    id: z.number(),
    type: z.string(),
    amount: z.coerce.number().default(0),
    mode: z.string().nullish(),
    modeReference: z.string().nullish(),
    receiptNo: z.string().nullish(),
    gstTreatment: z.string().nullish(),
    note: z.string().nullish(),
    createdAt: z.string(),
    invoiceId: z.number().nullish(),
    invoiceNo: z.string().nullish(),
  })
  .passthrough();
export type CautionTxn = z.infer<typeof cautionTxnSchema>;

export const cautionHistorySchema = z.object({
  balance: z.coerce.number().default(0),
  data: z
    .array(cautionTxnSchema)
    .nullish()
    .transform((v) => v ?? []),
  total: z.coerce.number().default(0),
});

/** Result of a deposit/refund/adjust/forfeit — the new balance + the txn. */
export const cautionResultSchema = z.object({
  balance: z.coerce.number().default(0),
  txn: cautionTxnSchema.nullish(),
});

const basketLineSchema = z
  .object({
    productId: z.number().nullish(),
    name: z.string().nullish(),
    qty: z.coerce.number().default(0),
    lineTotal: z.coerce.number().nullish(),
  })
  .passthrough();

export const cautionRequestSchema = z
  .object({
    id: z.number(),
    partyId: z.number(),
    party: z.object({ id: z.number(), name: z.string() }).nullish(),
    partyName: z.string().nullish(),
    amount: z.coerce.number().default(0),
    mode: z.string().nullish(),
    modeReference: z.string().nullish(),
    note: z.string().nullish(),
    status: z.string(),
    reviewNote: z.string().nullish(),
    createdAt: z.string(),
    basket: z.array(basketLineSchema).nullish(),
    basketValue: z.coerce.number().nullish(),
  })
  .passthrough();
export type CautionRequest = z.infer<typeof cautionRequestSchema>;

export const cautionRequestListSchema = z.object({
  data: z
    .array(cautionRequestSchema)
    .nullish()
    .transform((v) => v ?? []),
  total: z.coerce.number().default(0),
});

/** Display name for a request row regardless of which field the API used. */
export function requestPartyName(r: CautionRequest): string {
  return r.party?.name ?? r.partyName ?? `Party #${r.partyId}`;
}

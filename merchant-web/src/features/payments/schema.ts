import { z } from "zod";

/**
 * Payment shapes, mirroring the backend `payments` module (`/payments`).
 * A RECEIPT is money in from a party (against a SALE invoice); a PAYMENT is
 * money out to a vendor (against a PURCHASE invoice). Amounts are rupees
 * (Decimal serialised as a number), not paise. Voided payments carry
 * `voidedAt` and are excluded from balances by the backend.
 */

export const PAYMENT_MODES = ["CASH", "UPI", "NEFT", "RTGS", "CHEQUE", "CARD", "OTHER"] as const;
export type PaymentMode = (typeof PAYMENT_MODES)[number];

export const PAYMENT_MODE_LABELS: Record<string, string> = {
  CASH: "Cash",
  UPI: "UPI",
  NEFT: "NEFT",
  RTGS: "RTGS",
  CHEQUE: "Cheque",
  CARD: "Card",
  OTHER: "Other",
};

export const paymentSchema = z
  .object({
    id: z.number(),
    type: z.string(),
    referenceNo: z.string().nullish(),
    amount: z.coerce.number().default(0),
    mode: z.string().default("CASH"),
    modeReference: z.string().nullish(),
    paymentDate: z.string(),
    partyId: z.number().nullish(),
    vendorId: z.number().nullish(),
    invoiceId: z.number().nullish(),
    note: z.string().nullish(),
    voidedAt: z.string().nullish(),
    createdAt: z.string().optional(),
  })
  .passthrough();
export type Payment = z.infer<typeof paymentSchema>;

export const paymentListSchema = z.object({
  data: z
    .array(paymentSchema)
    .nullish()
    .transform((v) => v ?? []),
});

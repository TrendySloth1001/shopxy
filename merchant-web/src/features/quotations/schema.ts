import { z } from "zod";

/**
 * Quotation shapes, mirroring the backend `quotations` module (`/quotations`).
 * The merchant builds a priced bucket and sends it to a LINKED customer; the
 * customer accepts (which spawns a confirmed invoice) or declines. A customer
 * can also REQUEST a quote, which the merchant prices via "respond". Amounts
 * are rupees (Decimal serialised as a number).
 */

export const QUOTATION_STATUSES = [
  "REQUESTED",
  "PENDING",
  "ACCEPTED",
  "DECLINED",
  "CANCELLED",
  "EXPIRED",
] as const;
export type QuotationStatus = (typeof QUOTATION_STATUSES)[number];

export const QUOTATION_STATUS_LABELS: Record<string, string> = {
  REQUESTED: "Requested",
  PENDING: "Sent",
  ACCEPTED: "Accepted",
  DECLINED: "Declined",
  CANCELLED: "Cancelled",
  EXPIRED: "Expired",
};

export const QUOTATION_STATUS_CLASSES: Record<string, string> = {
  REQUESTED: "bg-brand-soft text-brand-strong",
  PENDING: "bg-accent-amber-soft text-accent-amber",
  ACCEPTED: "bg-success-soft text-success",
  DECLINED: "bg-error-soft text-error",
  CANCELLED: "bg-surface-tint text-muted",
  EXPIRED: "bg-surface-tint text-muted",
};

export const quotationLineSchema = z
  .object({
    productId: z.coerce.string(),
    name: z.string().nullish(),
    sku: z.string().nullish(),
    quantity: z.coerce.number().default(0),
    unitPrice: z.coerce.number().default(0),
    taxPercent: z.coerce.number().default(0),
    isPriceInclusive: z.boolean().default(false),
    discount: z.coerce.number().default(0),
    cessRate: z.coerce.number().default(0),
    imageUrl: z.string().nullish(),
    lineTotal: z.coerce.number().nullish(),
  })
  .passthrough();
export type QuotationLine = z.infer<typeof quotationLineSchema>;

export const quotationSchema = z
  .object({
    id: z.coerce.string(),
    quotationNo: z.string(),
    status: z.string(),
    partyId: z.coerce.string().nullish(),
    party: z.object({ id: z.coerce.string(), name: z.string() }).nullish(),
    items: z
      .array(quotationLineSchema)
      .nullish()
      .transform((v) => v ?? []),
    subtotal: z.coerce.number().default(0),
    taxAmount: z.coerce.number().default(0),
    total: z.coerce.number().default(0),
    note: z.string().nullish(),
    declineNote: z.string().nullish(),
    placeOfSupplyStateCode: z.string().nullish(),
    invoiceId: z.coerce.string().nullish(),
    invoice: z.object({ id: z.coerce.string(), invoiceNo: z.string() }).nullish(),
    requestedById: z.coerce.string().nullish(),
    respondedAt: z.string().nullish(),
    /// Set once the merchant files this quote out of THEIR working list. The
    /// customer keeps seeing it in their own — archiving is a filing
    /// decision, not a retraction.
    archivedAt: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().optional(),
  })
  .passthrough();
export type Quotation = z.infer<typeof quotationSchema>;

export const quotationListSchema = z.object({
  data: z
    .array(quotationSchema)
    .nullish()
    .transform((v) => v ?? []),
});

export function quotationPartyName(q: Quotation): string {
  return q.party?.name ?? "Customer";
}

/**
 * Whether the customer could still act on this quote. Archiving is refused in
 * these states: a quote the merchant can no longer see is one nobody chases,
 * and the accept would land against an invisible document.
 */
export function quotationAwaitsCounterparty(q: Quotation): boolean {
  return q.status === "PENDING" || q.status === "REQUESTED";
}

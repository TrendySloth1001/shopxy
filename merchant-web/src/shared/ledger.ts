import { z } from "zod";

/**
 * Ledger shapes shared by the vendor + party detail pages. Both
 * `/me/vendors/:id/ledger` and `/me/parties/:id/ledger` return the same
 * interleaved invoice/payment timeline with a server-computed running balance.
 */
export const ledgerEntrySchema = z
  .object({
    kind: z.enum(["invoice", "payment"]),
    id: z.number(),
    date: z.string(),
    label: z.string(),
    debit: z.coerce.number().default(0),
    credit: z.coerce.number().default(0),
    runningBalance: z.coerce.number().default(0),
    mode: z.string().nullish(),
    modeReference: z.string().nullish(),
    note: z.string().nullish(),
    invoiceId: z.number().nullish(),
    documentType: z.string().nullish(),
    status: z.string().nullish(),
  })
  .passthrough();
export type LedgerEntry = z.infer<typeof ledgerEntrySchema>;

export const ledgerSchema = z.object({
  balance: z.coerce.number().default(0),
  openingBalance: z.coerce.number().default(0),
  entries: z
    .array(ledgerEntrySchema)
    .nullish()
    .transform((v) => v ?? []),
});
export type Ledger = z.infer<typeof ledgerSchema>;

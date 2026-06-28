import { z } from "zod";

/**
 * Party ("customer") shapes, mirroring the backend `parties` module
 * (`/parties`). Like vendors but receivable-side, with challans instead of
 * stock-in.
 */

export const partySchema = z
  .object({
    id: z.number(),
    name: z.string(),
    contactName: z.string().nullish(),
    phone: z.string().nullish(),
    email: z.string().nullish(),
    address: z.string().nullish(),
    city: z.string().nullish(),
    state: z.string().nullish(),
    stateCode: z.string().nullish(),
    pinCode: z.string().nullish(),
    panNumber: z.string().nullish(),
    gstin: z.string().nullish(),
    isActive: z.boolean().default(true),
    isSystem: z.boolean().default(false),
    linkedUserId: z.number().nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    _count: z
      .object({
        challans: z.coerce.number().default(0),
        invoices: z.coerce.number().default(0),
      })
      .nullish(),
  })
  .passthrough();
export type Party = z.infer<typeof partySchema>;

export const partyListSchema = z.object({
  data: z
    .array(partySchema)
    .nullish()
    .transform((v) => v ?? []),
});

// The backend only selects `{ id, name }` for the linked user, so `email` is
// absent on the wire — keep it optional rather than failing the whole parse.
const linkedUserSchema = z.object({
  id: z.number(),
  name: z.string(),
  email: z.string().nullish(),
});

const partyTotalSchema = z.object({
  type: z.string(),
  count: z.coerce.number().default(0),
  total: z.coerce.number().default(0),
});

const partyInvoiceRefSchema = z
  .object({
    id: z.number(),
    invoiceNo: z.string(),
    type: z.string(),
    status: z.string(),
    invoiceDate: z.string(),
    total: z.coerce.number().default(0),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type PartyInvoiceRef = z.infer<typeof partyInvoiceRefSchema>;

const partyChallanRefSchema = z
  .object({
    id: z.number(),
    challanNo: z.string(),
    status: z.string(),
    createdAt: z.string(),
    invoiceId: z.number().nullish(),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type PartyChallanRef = z.infer<typeof partyChallanRefSchema>;

export const partyOverviewSchema = z.object({
  party: z
    .object({
      id: z.number(),
      name: z.string(),
      contactName: z.string().nullish(),
      phone: z.string().nullish(),
      email: z.string().nullish(),
      address: z.string().nullish(),
      city: z.string().nullish(),
      state: z.string().nullish(),
      stateCode: z.string().nullish(),
      pinCode: z.string().nullish(),
      panNumber: z.string().nullish(),
      gstin: z.string().nullish(),
      isActive: z.boolean().default(true),
      isSystem: z.boolean().default(false),
      createdAt: z.string().optional(),
      updatedAt: z.string().optional(),
      linkedUserId: z.number().nullish(),
      linkedUser: linkedUserSchema.nullish(),
    })
    .passthrough(),
  counts: z.object({
    invoices: z.coerce.number().default(0),
    challans: z.coerce.number().default(0),
  }),
  totals: z
    .array(partyTotalSchema)
    .nullish()
    .transform((v) => v ?? []),
  recentInvoices: z
    .array(partyInvoiceRefSchema)
    .nullish()
    .transform((v) => v ?? []),
  recentChallans: z
    .array(partyChallanRefSchema)
    .nullish()
    .transform((v) => v ?? []),
  lastActivityAt: z.string().nullish(),
  balance: z.coerce.number().default(0),
});
export type PartyOverview = z.infer<typeof partyOverviewSchema>;

export function partyChallanCount(p: Party): number {
  return p._count?.challans ?? 0;
}
export function partyInvoiceCount(p: Party): number {
  return p._count?.invoices ?? 0;
}

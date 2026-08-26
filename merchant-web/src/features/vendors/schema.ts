import { z } from "zod";

const linkedUserSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  email: z.string().nullish(),
  avatarUrl: z.string().nullish(),
});

export const vendorSchema = z
  .object({
    id: z.coerce.string(),
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
    linkedUserId: z.coerce.string().nullish(),
    linkedUser: linkedUserSchema.nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    _count: z
      .object({
        stockTransactions: z.coerce.number().default(0),
        invoices: z.coerce.number().default(0),
      })
      .nullish(),
  })
  .passthrough();
export type Vendor = z.infer<typeof vendorSchema>;

export const vendorListSchema = z.object({
  data: z
    .array(vendorSchema)
    .nullish()
    .transform((v) => v ?? []),
  total: z.coerce.number().default(0),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
});

const vendorTotalSchema = z.object({
  type: z.string(),
  count: z.coerce.number().default(0),
  total: z.coerce.number().default(0),
});

const vendorInvoiceRefSchema = z
  .object({
    id: z.coerce.string(),
    invoiceNo: z.string(),
    type: z.string(),
    status: z.string(),
    invoiceDate: z.string(),
    total: z.coerce.number().default(0),
    _count: z.object({ items: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type VendorInvoiceRef = z.infer<typeof vendorInvoiceRefSchema>;

const vendorStockInRefSchema = z
  .object({
    id: z.coerce.string(),
    quantity: z.coerce.number().default(0),
    unitCost: z.coerce.number().nullish(),
    totalValue: z.coerce.number().nullish(),
    createdAt: z.string(),
    reasonCode: z.string().nullish(),
    sourceType: z.string().nullish(),
    product: z
      .object({
        id: z.coerce.string(),
        name: z.string(),
        sku: z.string().nullish(),
        unit: z.string().nullish(),
      })
      .nullish(),
  })
  .passthrough();
export type VendorStockInRef = z.infer<typeof vendorStockInRefSchema>;

export const vendorOverviewSchema = z.object({
  vendor: z
    .object({
      id: z.coerce.string(),
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
      createdAt: z.string().optional(),
      updatedAt: z.string().optional(),
      linkedUserId: z.coerce.string().nullish(),
      linkedUser: linkedUserSchema.nullish(),
    })
    .passthrough(),
  counts: z.object({
    invoices: z.coerce.number().default(0),
    stockIns: z.coerce.number().default(0),
  }),
  totals: z
    .array(vendorTotalSchema)
    .nullish()
    .transform((v) => v ?? []),
  recentInvoices: z
    .array(vendorInvoiceRefSchema)
    .nullish()
    .transform((v) => v ?? []),
  recentStockIns: z
    .array(vendorStockInRefSchema)
    .nullish()
    .transform((v) => v ?? []),
  lastActivityAt: z.string().nullish(),
  balance: z.coerce.number().default(0),
});
export type VendorOverview = z.infer<typeof vendorOverviewSchema>;

export function vendorTxnCount(v: Vendor): number {
  return v._count?.stockTransactions ?? 0;
}
export function vendorInvoiceCount(v: Vendor): number {
  return v._count?.invoices ?? 0;
}

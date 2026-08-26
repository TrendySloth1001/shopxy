import { z } from "zod";
import { zNum } from "@/shared/zod";

export const pageMetaSchema = z.object({
  pagination: z.object({
    page: z.number(),
    limit: z.number(),
    total: z.coerce.number(),
    totalPages: z.number(),
  }),
});

export const invoiceListItemSchema = z.object({
  id: z.coerce.string(),
  invoiceNo: z.string(),
  type: z.string().optional(),
  status: z.string().optional(),
  total: z.coerce.number(),
  subtotal: z.coerce.number().optional(),
  taxAmount: z.coerce.number().optional(),
  discount: z.coerce.number().default(0),
  invoiceDate: z.string(),
  createdAt: z.string(),
  _count: z.object({ items: z.number() }).optional(),
});
export type InvoiceListItem = z.infer<typeof invoiceListItemSchema>;

export const partyRowSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  email: z.string().nullable().optional(),
  phone: z.string().nullable().optional(),
});
export type PartyRow = z.infer<typeof partyRowSchema>;

export const invoicesPageSchema = pageMetaSchema.extend({
  data: z.array(invoiceListItemSchema),
  party: partyRowSchema.optional(),
  vendor: partyRowSchema.optional(),
});
export type InvoicesPage = z.infer<typeof invoicesPageSchema>;

export const invoiceItemSchema = z.object({
  id: z.coerce.string(),
  productName: z.string(),
  productSku: z.string().nullable().optional(),
  hsn: z.string().nullable().optional(),
  unit: z.string(),
  quantity: z.coerce.number(),
  unitPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
  discount: z.coerce.number().default(0),
  total: z.coerce.number(),
});
export type InvoiceItem = z.infer<typeof invoiceItemSchema>;

export const invoiceDetailSchema = z.object({
  id: z.coerce.string(),
  invoiceNo: z.string(),
  type: z.string().optional(),
  status: z.string(),
  total: z.coerce.number(),
  subtotal: z.coerce.number(),
  taxAmount: z.coerce.number(),
  discount: z.coerce.number().default(0),
  invoiceDate: z.string(),
  customerName: z.string().nullable().optional(),
  customerPhone: z.string().nullable().optional(),
  customerGstin: z.string().nullable().optional(),
  vendorName: z.string().nullable().optional(),
  vendorPhone: z.string().nullable().optional(),
  vendorGstin: z.string().nullable().optional(),
  note: z.string().nullable().optional(),
  createdAt: z.string(),
  items: z.array(invoiceItemSchema),
});
export type InvoiceDetail = z.infer<typeof invoiceDetailSchema>;

export const quotationLineSchema = z.object({
  productId: z.coerce.string().nullable().optional(),
  name: z.string(),
  sku: z.string().nullable().optional(),
  quantity: z.coerce.number(),
  unitPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
  cessRate: zNum.default(0).optional(),
  discount: z.coerce.number().default(0).optional(),
  imageUrl: z.string().nullable().optional(),
  lineTotal: z.coerce.number(),
});
export type QuotationLine = z.infer<typeof quotationLineSchema>;

export const quotationSchema = z.object({
  id: z.coerce.string(),
  shopId: z.coerce.string(),
  partyId: z.coerce.string(),
  quotationNo: z.string(),
  status: z.string(),
  items: z.array(quotationLineSchema),
  subtotal: z.coerce.number(),
  taxAmount: z.coerce.number(),
  total: z.coerce.number(),
  note: z.string().nullable().optional(),
  placeOfSupplyStateCode: z.string().nullable().optional(),
  declineNote: z.string().nullable().optional(),
  requestedById: z.coerce.string().nullable().optional(),
  respondedAt: z.string().nullable().optional(),
  invoiceId: z.coerce.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string().optional(),
  party: z.object({ id: z.coerce.string(), name: z.string() }).optional(),
  invoice: z.object({ id: z.coerce.string(), invoiceNo: z.string() }).nullable().optional(),
});
export type Quotation = z.infer<typeof quotationSchema>;

export const quotationsPageSchema = pageMetaSchema.extend({
  data: z.array(quotationSchema),
});
export type QuotationsPage = z.infer<typeof quotationsPageSchema>;

export const catalogProductSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  sku: z.string(),
  unit: z.string(),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
  stockQuantity: z.coerce.number().nullable().optional(),
  categoryId: z.coerce.string().nullable().optional(),
  category: z.object({ id: z.coerce.string(), name: z.string(), iconName: z.string().nullable().optional() }).nullable().optional(),
  images: z.array(z.object({ id: z.coerce.string(), url: z.string() })).optional(),
});
export type CatalogProduct = z.infer<typeof catalogProductSchema>;

export const catalogPageSchema = z.object({
  data: z.array(catalogProductSchema),
  pagination: z.object({
    page: z.number(),
    limit: z.number(),
    total: z.coerce.number(),
    totalPages: z.number(),
  }),
});
export type CatalogPage = z.infer<typeof catalogPageSchema>;

export const catalogCategorySchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  imageUrl: z.string().nullable().optional(),
  iconName: z.string().nullable().optional(),
  _count: z.object({ products: z.number() }).optional(),
});
export type CatalogCategory = z.infer<typeof catalogCategorySchema>;

export interface BasketItem {
  productId: string;
  name: string;
  sku?: string;
  quantity: number;
  unitPrice: number;
  taxPercent?: number;
  imageUrl?: string | null;
}

export type MerchantRole = "party" | "vendor";

export function txnIncreasesHeld(type: string): boolean {
  return type === "DEPOSIT";
}

export function txnLabel(type: string): string {
  switch (type) {
    case "DEPOSIT": return "Deposit";
    case "REFUND": return "Refund";
    case "FORFEIT": return "Forfeited";
    case "ADJUSTMENT": return "Adjusted to invoice";
    default: return type;
  }
}

export function requestStatusLabel(status: string): {
  label: string;
  color: string;
  bg: string;
} {
  switch (status) {
    case "PENDING":
      return { label: "Pending", color: "text-warning", bg: "bg-warning-soft" };
    case "APPROVED":
      return { label: "Approved", color: "text-success", bg: "bg-success-soft" };
    case "REJECTED":
      return { label: "Declined", color: "text-error", bg: "bg-error-soft" };
    default:
      return { label: "Cancelled", color: "text-muted", bg: "bg-surface-tint" };
  }
}

export function quotationStatusStyle(status: string): {
  label: string;
  color: string;
  bg: string;
} {
  switch (status) {
    case "REQUESTED":
      return { label: "Requested", color: "text-brand", bg: "bg-brand-soft" };
    case "PENDING":
      return { label: "Awaiting you", color: "text-warning", bg: "bg-warning-soft" };
    case "ACCEPTED":
      return { label: "Accepted", color: "text-success", bg: "bg-success-soft" };
    case "DECLINED":
      return { label: "Declined", color: "text-error", bg: "bg-error-soft" };
    case "CANCELLED":
      return { label: "Withdrawn", color: "text-muted", bg: "bg-surface-tint" };
    case "EXPIRED":
      return { label: "Expired", color: "text-muted", bg: "bg-surface-tint" };
    default:
      return { label: status, color: "text-muted", bg: "bg-surface-tint" };
  }
}

import { z } from "zod";

// ─── Shared sub-schemas ───────────────────────────────────────────────────────

export const shopSummarySchema = z.object({
  id: z.number(),
  name: z.string(),
  shopName: z.string().nullable().optional(),
  returnsEnabled: z.boolean().default(false),
  returnWindowDays: z.number().default(7),
  refundMode: z.string().nullable().optional(),
  returnPolicyNote: z.string().nullable().optional(),
});
export type ShopSummary = z.infer<typeof shopSummarySchema>;

export const shopOrderPreviewSchema = z.object({
  id: z.number(),
  shopId: z.number(),
  status: z.string(),
  estimatedTotal: z.coerce.number(),
  invoiceId: z.number().nullable().optional(),
  decidedAt: z.string().nullable().optional(),
  shop: shopSummarySchema.nullable().optional(),
  _count: z.object({ items: z.number() }).optional(),
  itemsPreview: z
    .array(z.object({ productName: z.string(), quantity: z.coerce.number(), unit: z.string() }))
    .optional(),
});
export type ShopOrderPreview = z.infer<typeof shopOrderPreviewSchema>;

export const customerOrderSchema = z.object({
  id: z.number(),
  customerName: z.string().default(""),
  customerPhone: z.string().nullable().optional(),
  customerAddress: z.string().nullable().optional(),
  estimatedTotal: z.coerce.number(),
  couponDiscount: z.coerce.number().default(0),
  walletPaid: z.coerce.number().default(0),
  paymentStatus: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
  _count: z.object({ shopOrders: z.number() }).optional(),
  shopOrders: z.array(shopOrderPreviewSchema),
  // Derived on list — some servers return these
  needsOnlinePayment: z.boolean().optional(),
  payableRemainder: z.coerce.number().optional(),
  note: z.string().nullable().optional(),
});
export type CustomerOrder = z.infer<typeof customerOrderSchema>;

// ─── Order detail ────────────────────────────────────────────────────────────

export const orderEventSchema = z.object({
  id: z.number(),
  type: z.string(),
  occurredAt: z.string(),
  courier: z.string().nullable().optional(),
  awb: z.string().nullable().optional(),
  eta: z.string().nullable().optional(),
  note: z.string().nullable().optional(),
});
export type OrderEvent = z.infer<typeof orderEventSchema>;

export const orderInvoiceRefSchema = z.object({
  id: z.number(),
  invoiceNo: z.string(),
  type: z.string().optional(),
  status: z.string().optional(),
  total: z.coerce.number(),
  invoiceDate: z.string().optional(),
  paidAmount: z.coerce.number(),
  balanceDue: z.number().optional(),
  paymentStatus: z.string(),
});
export type OrderInvoiceRef = z.infer<typeof orderInvoiceRefSchema>;

export const orderItemSchema = z.object({
  id: z.number(),
  productId: z.number(),
  productName: z.string(),
  productSku: z.string().optional(),
  unit: z.string(),
  quantity: z.coerce.number(),
  unitPrice: z.coerce.number(),
  total: z.coerce.number(),
  product: z
    .object({
      stockQuantity: z.coerce.number().optional(),
      isActive: z.boolean().optional(),
      images: z.array(z.object({ url: z.string() })).optional(),
    })
    .optional(),
});
export type OrderItem = z.infer<typeof orderItemSchema>;

export const shopOrderDetailSchema = z.object({
  id: z.number(),
  shopId: z.number(),
  status: z.string(),
  estimatedTotal: z.coerce.number(),
  invoiceId: z.number().nullable().optional(),
  customerAddress: z.string().nullable().optional(),
  note: z.string().nullable().optional(),
  createdAt: z.string(),
  decidedAt: z.string().nullable().optional(),
  decisionNote: z.string().nullable().optional(),
  shop: shopSummarySchema.nullable().optional(),
  invoice: orderInvoiceRefSchema.nullable().optional(),
  items: z.array(orderItemSchema),
  events: z.array(orderEventSchema),
  canCancel: z.boolean(),
  canReturn: z.boolean(),
  cancellationPolicy: z.string().nullable().optional(),
  deliveredAt: z.string().nullable().optional(),
  linkedPartyId: z.number().nullable().optional(),
});
export type ShopOrderDetail = z.infer<typeof shopOrderDetailSchema>;

export const customerOrderDetailSchema = customerOrderSchema.extend({
  shopOrders: z.array(shopOrderDetailSchema),
});
export type CustomerOrderDetail = z.infer<typeof customerOrderDetailSchema>;

// ─── Paginated list response ─────────────────────────────────────────────────

export const ordersPageSchema = z.object({
  data: z.array(customerOrderSchema),
  pagination: z.object({
    page: z.number(),
    limit: z.number(),
    total: z.coerce.number(),
    totalPages: z.number(),
  }),
});
export type OrdersPage = z.infer<typeof ordersPageSchema>;

// ─── Reorder response ────────────────────────────────────────────────────────

export const reorderItemSchema = z.object({
  productId: z.number(),
  quantity: z.coerce.number(),
  product: z.object({
    id: z.number(),
    name: z.string(),
    sku: z.string().optional(),
    unit: z.string().optional(),
    sellingPrice: z.coerce.number().optional(),
    images: z.array(z.object({ url: z.string() })).optional(),
  }),
});

export const reorderResultSchema = z.object({
  items: z.array(reorderItemSchema),
  skipped: z.array(
    z.object({
      productId: z.number(),
      productName: z.string(),
      reason: z.enum(["UNAVAILABLE", "OWN_SHOP"]),
    }),
  ),
});
export type ReorderResult = z.infer<typeof reorderResultSchema>;

// ─── Pay session ─────────────────────────────────────────────────────────────

export const paySessionSchema = z.object({
  intentId: z.number(),
  provider: z.literal("RAZORPAY"),
  providerOrderRef: z.string(),
  amount: z.coerce.number(),
  currency: z.literal("INR"),
  clientParams: z.object({
    key: z.string(),
    order_id: z.string(),
    amount: z.coerce.number(),
    currency: z.string().optional(),
  }),
  reused: z.boolean(),
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Does this order have unpaid online-payment orders? */
export function orderNeedsOnlinePayment(order: CustomerOrder): boolean {
  if (typeof order.needsOnlinePayment === "boolean") return order.needsOnlinePayment;
  // Derive from paymentStatus if the flag wasn't sent
  return order.paymentStatus === "PENDING";
}

/** Get payable amount from order */
export function orderPayableRemainder(order: CustomerOrder): number {
  if (typeof order.payableRemainder === "number") return order.payableRemainder;
  // Derive: estimatedTotal minus wallet/coupon, rounded to 2 dp (matches backend round2)
  const wallet = order.walletPaid ?? 0;
  const coupon = order.couponDiscount ?? 0;
  const raw = Math.max(0, order.estimatedTotal - wallet - coupon);
  return Math.round(raw * 100) / 100;
}

export function isChildPending(s: ShopOrderPreview) { return s.status === "PENDING"; }
export function isChildConfirmed(s: ShopOrderPreview) { return s.status === "CONFIRMED"; }
export function isChildRejected(s: ShopOrderPreview) { return s.status === "REJECTED"; }
export function isChildCancelled(s: ShopOrderPreview) { return s.status === "CANCELLED"; }

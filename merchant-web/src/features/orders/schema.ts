import { z } from "zod";

/**
 * Order (purchase-request) shapes, mirroring the backend
 * (`backend/src/modules/purchase-requests/*`). Decimal money/qty fields arrive
 * as strings → coerced to numbers; nullable arrays normalise to `[]`; unknown
 * fields pass through. Validated at the BFF boundary so screens work with a
 * clean, typed object.
 *
 * "Orders" on the merchant side are `PurchaseRequest` rows: a customer places a
 * cart → one request per shop lands in the merchant inbox → the merchant
 * confirms (materialising a SALE invoice) or declines.
 */

const num = z.coerce.number();

/** Array that may arrive as null/undefined → always an array. */
const arr = <T extends z.ZodTypeAny>(s: T) =>
  z
    .array(s)
    .nullish()
    .transform((v) => v ?? []);

/** Statuses the backend can report. PROCESSING is a transient confirm state. */
export const ORDER_STATUSES = [
  "PENDING",
  "CONFIRMED",
  "REJECTED",
  "CANCELLED",
] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

export const orderPartySchema = z
  .object({
    id: z.number(),
    name: z.string().nullish(),
    linkedUserId: z.number().nullish(),
  })
  .passthrough();
export type OrderParty = z.infer<typeof orderPartySchema>;

/** Compact item preview attached to inbox rows. */
export const orderItemPreviewSchema = z.object({
  productName: z.string(),
  quantity: num.default(0),
  unit: z.string().default("PCS"),
});
export type OrderItemPreview = z.infer<typeof orderItemPreviewSchema>;

/** A single inbox row. */
export const orderListRowSchema = z
  .object({
    id: z.number(),
    status: z.string(),
    customerName: z.string(),
    customerPhone: z.string().nullish(),
    customerEmail: z.string().nullish(),
    estimatedTotal: num.default(0),
    note: z.string().nullish(),
    invoiceId: z.number().nullish(),
    createdAt: z.string(),
    decidedAt: z.string().nullish(),
    party: orderPartySchema.nullish(),
    _count: z.object({ items: num.default(0) }).nullish(),
    itemsPreview: arr(orderItemPreviewSchema),
  })
  .passthrough();
export type OrderListRow = z.infer<typeof orderListRowSchema>;

export const orderListSchema = z.object({
  data: z.array(orderListRowSchema),
  pagination: z
    .object({
      total: num.default(0),
      page: num.optional(),
      limit: num.optional(),
    })
    .passthrough(),
});
export type OrderList = z.infer<typeof orderListSchema>;

/** Detail line item — carries the linked product's live stock + first image. */
export const orderItemSchema = z
  .object({
    id: z.number(),
    productId: z.number(),
    productName: z.string(),
    productSku: z.string(),
    unit: z.string().default("PCS"),
    quantity: num.default(0),
    unitPrice: num.default(0),
    total: num.default(0),
    product: z
      .object({
        stockQuantity: num.nullish(),
        isActive: z.boolean().nullish(),
        images: arr(z.object({ url: z.string() }).passthrough()),
      })
      .nullish(),
  })
  .passthrough();
export type OrderItem = z.infer<typeof orderItemSchema>;

/** Linked invoice with the derived payment summary the backend attaches. */
export const orderInvoiceSchema = z
  .object({
    id: z.number(),
    invoiceNo: z.string(),
    status: z.string().nullish(),
    total: num.nullish(),
    paymentStatus: z.string().nullish(),
    paidAmount: num.nullish(),
    balanceDue: num.nullish(),
  })
  .passthrough();
export type OrderInvoice = z.infer<typeof orderInvoiceSchema>;

/** Shipping-event timeline entry (PACKED / SHIPPED / …). */
export const orderEventSchema = z
  .object({
    id: z.number(),
    type: z.string(),
    occurredAt: z.string(),
    courier: z.string().nullish(),
    awb: z.string().nullish(),
    eta: z.string().nullish(),
    note: z.string().nullish(),
  })
  .passthrough();
export type OrderEvent = z.infer<typeof orderEventSchema>;

export const orderDetailSchema = orderListRowSchema
  .extend({
    customerAddress: z.string().nullish(),
    customerUserId: z.number().nullish(),
    decisionNote: z.string().nullish(),
    invoice: orderInvoiceSchema.nullish(),
    items: arr(orderItemSchema),
    events: arr(orderEventSchema),
  })
  .passthrough();
export type OrderDetail = z.infer<typeof orderDetailSchema>;

/** Successful confirm response — the materialised invoice id + number. */
export const confirmResultSchema = z
  .object({
    invoice: z.object({ id: z.number(), invoiceNo: z.string() }).passthrough(),
  })
  .passthrough();
export type ConfirmResult = z.infer<typeof confirmResultSchema>;

export const pendingCountSchema = z.object({ count: num.default(0) });

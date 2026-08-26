import { z } from "zod";

const num = z.coerce.number();

const arr = <T extends z.ZodTypeAny>(s: T) =>
  z
    .array(s)
    .nullish()
    .transform((v) => v ?? []);

export const ORDER_STATUSES = [
  "PENDING",
  "CONFIRMED",
  "REJECTED",
  "CANCELLED",
] as const;
export type OrderStatus = (typeof ORDER_STATUSES)[number];

export const orderPartySchema = z
  .object({
    id: z.coerce.string(),
    name: z.string().nullish(),
    linkedUserId: z.coerce.string().nullish(),
  })
  .passthrough();
export type OrderParty = z.infer<typeof orderPartySchema>;

export const orderItemPreviewSchema = z.object({
  productName: z.string(),
  quantity: num.default(0),
  unit: z.string().default("PCS"),
});
export type OrderItemPreview = z.infer<typeof orderItemPreviewSchema>;

export const orderListRowSchema = z
  .object({
    id: z.coerce.string(),
    status: z.string(),
    customerName: z.string(),
    customerPhone: z.string().nullish(),
    customerEmail: z.string().nullish(),
    estimatedTotal: num.default(0),
    note: z.string().nullish(),
    invoiceId: z.coerce.string().nullish(),
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

export const orderItemSchema = z
  .object({
    id: z.coerce.string(),
    productId: z.coerce.string(),
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

export const orderInvoiceSchema = z
  .object({
    id: z.coerce.string(),
    invoiceNo: z.string(),
    status: z.string().nullish(),
    total: num.nullish(),
    paymentStatus: z.string().nullish(),
    paidAmount: num.nullish(),
    balanceDue: num.nullish(),
  })
  .passthrough();
export type OrderInvoice = z.infer<typeof orderInvoiceSchema>;

export const orderEventSchema = z
  .object({
    id: z.coerce.string(),
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
    customerUserId: z.coerce.string().nullish(),
    decisionNote: z.string().nullish(),
    invoice: orderInvoiceSchema.nullish(),
    items: arr(orderItemSchema),
    events: arr(orderEventSchema),
  })
  .passthrough();
export type OrderDetail = z.infer<typeof orderDetailSchema>;

export const confirmResultSchema = z
  .object({
    invoice: z.object({ id: z.coerce.string(), invoiceNo: z.string() }).passthrough(),
  })
  .passthrough();
export type ConfirmResult = z.infer<typeof confirmResultSchema>;

export const pendingCountSchema = z.object({ count: num.default(0) });

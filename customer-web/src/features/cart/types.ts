import { z } from "zod";
import { zNum } from "@/shared/zod";

export const cartProductSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  sku: z.string().nullable().optional(),
  unit: z.string().nullable().optional(),
  mrp: zNum,
  sellingPrice: zNum,
  taxPercent: zNum.default(0),
  stockQuantity: zNum,
  isActive: z.boolean(),
  isPublished: z.boolean(),
  categoryId: z.coerce.string().nullable().optional(),
  category: z
    .object({ id: z.coerce.string(), name: z.string(), iconName: z.string().nullable().optional() })
    .nullable()
    .optional(),
  images: z.array(z.object({ url: z.string(), sortOrder: z.number() })).default([]),
  shop: z.object({ id: z.coerce.string(), name: z.string(), slug: z.string() }),
});

export type CartProduct = z.infer<typeof cartProductSchema>;

export const cartItemSchema = z.object({
  id: z.coerce.string(),
  productId: z.coerce.string(),
  quantity: zNum,
  updatedAt: z.string(),
  product: cartProductSchema,
});

export type CartItem = z.infer<typeof cartItemSchema>;

export const cartResponseSchema = z.object({
  data: z.array(cartItemSchema),
});

export const setQtyResponseSchema = cartItemSchema.extend({
  capped: z.boolean(),
});

export type SetQtyResponse = z.infer<typeof setQtyResponseSchema>;

export const mergeBffResponseSchema = z.object({
  data: z.array(cartItemSchema),
});

export interface GuestLine {
  productId: string;
  quantity: number;
  snapshot: {
    name: string;
    imageUrl: string;
    sellingPrice: number;
    mrp: number;
    shopName: string;
    shopSlug: string;
    unit?: string | null;
    stockQuantity: number;
  };
}

export const GUEST_CART_KEY = "sx_guest_cart";
export const MAX_LINE_QTY = 999;

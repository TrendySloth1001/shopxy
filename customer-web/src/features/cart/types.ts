import { z } from "zod";

// ── Product sub-shape inside a cart line ──────────────────────────────────────

export const cartProductSchema = z.object({
  id: z.number(),
  name: z.string(),
  sku: z.string().nullable().optional(),
  unit: z.string().nullable().optional(),
  mrp: z.number(),
  sellingPrice: z.number(),
  taxPercent: z.number().default(0),
  stockQuantity: z.number(),
  isActive: z.boolean(),
  isPublished: z.boolean(),
  categoryId: z.number().nullable().optional(),
  category: z
    .object({ id: z.number(), name: z.string(), iconName: z.string().nullable().optional() })
    .nullable()
    .optional(),
  images: z.array(z.object({ url: z.string(), sortOrder: z.number() })).default([]),
  shop: z.object({ id: z.number(), name: z.string(), slug: z.string() }),
});

export type CartProduct = z.infer<typeof cartProductSchema>;

// ── Cart line ─────────────────────────────────────────────────────────────────

export const cartItemSchema = z.object({
  id: z.number(),
  productId: z.number(),
  quantity: z.number(),
  updatedAt: z.string(),
  product: cartProductSchema,
});

export type CartItem = z.infer<typeof cartItemSchema>;

export const cartResponseSchema = z.object({
  data: z.array(cartItemSchema),
});

// ── PUT /me/cart/:productId response ─────────────────────────────────────────

export const setQtyResponseSchema = cartItemSchema.extend({
  capped: z.boolean(),
});

export type SetQtyResponse = z.infer<typeof setQtyResponseSchema>;

// ── Merge request/response ────────────────────────────────────────────────────

export const mergeBffResponseSchema = z.object({
  data: z.array(cartItemSchema),
});

// ── Local guest cart (localStorage) ──────────────────────────────────────────

export interface GuestLine {
  productId: number;
  quantity: number;
  /** Cached display data so the guest cart can render without a server round-trip. */
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

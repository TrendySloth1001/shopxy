import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { isOutputGstRegistered } from '../invoices/gst-registration-gate.js';

const cartProductSelect = {
  id: true,
  name: true,
  sku: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  taxPercent: true,
  stockQuantity: true,
  isActive: true,
  isPublished: true,
  categoryId: true,
  category: { select: { id: true, name: true, iconName: true } },
  images: {
    select: { url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
    take: 1,
  },
  shop: {
    select: {
      id: true,
      name: true,
      slug: true,
      owner: {
        select: {
          shopGstin: true,
          registrationType: true,
          gstEffectiveFrom: true,
        },
      },
    },
  },
} satisfies Prisma.ProductSelect;

const MAX_LINE_QUANTITY = 999;

export class CartService {
  async list(userId: number) {
    const rows = await prisma.cartItem.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        productId: true,
        quantity: true,
        updatedAt: true,
        product: { select: cartProductSelect },
      },
    });

    const staleIds = rows
      .filter((r) => !r.product || !r.product.isActive || !r.product.isPublished)
      .map((r) => r.id);
    if (staleIds.length) {
      await prisma.cartItem.deleteMany({ where: { id: { in: staleIds } } });
    }

    return rows
      .filter((r) => r.product && r.product.isActive && r.product.isPublished)
      .map((r) => {
        const { owner, ...shop } = r.product!.shop;
        return {
          id: r.id,
          productId: r.productId,
          quantity: Number(r.quantity),
          updatedAt: r.updatedAt,
          product: {
            ...r.product!,
            shop: {
              ...shop,
              gstRegistered: isOutputGstRegistered(owner, new Date()),
            },
          },
        };
      });
  }

  async setQuantity(userId: number, productId: number, quantity: number) {
    if (quantity <= 0) {
      await prisma.cartItem.deleteMany({ where: { userId, productId } });
      return null;
    }

    const product = await prisma.product.findFirst({
      where: { id: productId, isActive: true, isPublished: true, shop: { isPublished: true } },
      select: { id: true, stockQuantity: true },
    });
    if (!product) return { error: 'PRODUCT_NOT_FOUND' as const };

    const stock = Number(product.stockQuantity);
    if (stock <= 0) return { error: 'OUT_OF_STOCK' as const };

    const capped = Math.min(quantity, stock, MAX_LINE_QUANTITY);

    const existing = await prisma.cartItem.findFirst({
      where: { userId, productId, variantId: null },
      select: { id: true },
    });
    const row = existing
      ? await prisma.cartItem.update({
          where: { id: existing.id },
          data: { quantity: capped },
          select: {
            id: true,
            productId: true,
            quantity: true,
            updatedAt: true,
            product: { select: cartProductSelect },
          },
        })
      : await prisma.cartItem.create({
          data: { userId, productId, quantity: capped },
          select: {
            id: true,
            productId: true,
            quantity: true,
            updatedAt: true,
            product: { select: cartProductSelect },
          },
        });

    return {
      id: row.id,
      productId: row.productId,
      quantity: Number(row.quantity),
      capped: capped < quantity,
      updatedAt: row.updatedAt,
      product: row.product,
    };
  }

  async remove(userId: number, productId: number) {
    await prisma.cartItem.deleteMany({ where: { userId, productId } });
  }

  async clear(userId: number) {
    await prisma.cartItem.deleteMany({ where: { userId } });
  }

  async merge(
    userId: number,
    items: { productId: number; quantity: number }[],
  ) {
    if (items.length === 0) return await this.list(userId);

    const ids = Array.from(new Set(items.map((i) => i.productId)));
    const products = await prisma.product.findMany({
      where: { id: { in: ids }, isActive: true, isPublished: true, shop: { isPublished: true } },
      select: { id: true, stockQuantity: true },
    });
    const stockById = new Map(
      products.map((p) => [p.id, Number(p.stockQuantity)]),
    );

    const existing = await prisma.cartItem.findMany({
      where: { userId, productId: { in: ids } },
      select: { productId: true, quantity: true },
    });
    const existingById = new Map(
      existing.map((r) => [r.productId, Number(r.quantity)]),
    );

    const wantById = new Map<number, number>();
    for (const item of items) {
      if (!stockById.has(item.productId)) continue;
      const prev = wantById.get(item.productId) ?? 0;
      wantById.set(item.productId, prev + Math.max(0, item.quantity));
    }

    for (const [productId, addQty] of wantById) {
      const stock = stockById.get(productId)!;
      if (stock <= 0) continue;
      const base = existingById.get(productId) ?? 0;
      const merged = Math.min(base + addQty, stock, MAX_LINE_QUANTITY);
      if (merged <= 0) continue;
      const existingLine = await prisma.cartItem.findFirst({
        where: { userId, productId, variantId: null },
        select: { id: true },
      });
      if (existingLine) {
        await prisma.cartItem.update({
          where: { id: existingLine.id },
          data: { quantity: merged },
        });
      } else {
        await prisma.cartItem.create({
          data: { userId, productId, quantity: merged },
        });
      }
    }

    return await this.list(userId);
  }
}

export const cartService = new CartService();

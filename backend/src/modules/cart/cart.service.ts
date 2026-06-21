import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

/// Product fields the customer cart UI needs to render a line: name,
/// pricing, primary image, stock, and the owning shop so the "Sold by"
/// chip works. Tighter than the catalog detail select to keep the
/// payload small (cart is fetched on every app open).
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
  shop: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.ProductSelect;

/// Hard cap on a single line — matches the customer app's
/// `kMaxLineQuantity`. The two numbers must agree or the server will
/// reject quantities the client thinks are fine.
const MAX_LINE_QUANTITY = 999;

export class CartService {
  /// Returns the user's full cart in a render-ready shape. Most-recent
  /// updated first so a just-tapped item floats to the top — matches
  /// how shopping carts behave everywhere. Inactive / unpublished
  /// products are dropped from the response (and from the DB) so the
  /// customer doesn't see ghost rows after a merchant unpublishes a
  /// product they had carted.
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

    // Drop and purge any lines whose product was deactivated /
    // unpublished since the user added it — keeps the cart honest
    // without forcing the customer to discover the deletion through
    // a checkout failure.
    const staleIds = rows
      .filter((r) => !r.product || !r.product.isActive || !r.product.isPublished)
      .map((r) => r.id);
    if (staleIds.length) {
      await prisma.cartItem.deleteMany({ where: { id: { in: staleIds } } });
    }

    return rows
      .filter((r) => r.product && r.product.isActive && r.product.isPublished)
      .map((r) => ({
        id: r.id,
        productId: r.productId,
        quantity: Number(r.quantity),
        updatedAt: r.updatedAt,
        product: r.product,
      }));
  }

  /// Set the absolute quantity on a line. Quantity ≤ 0 removes the
  /// line. Returns the updated line (or null when removed). Caller
  /// must pre-validate `productId` is a positive int.
  async setQuantity(userId: number, productId: number, quantity: number) {
    if (quantity <= 0) {
      await prisma.cartItem.deleteMany({ where: { userId, productId } });
      return null;
    }

    const product = await prisma.product.findFirst({
      where: { id: productId, isActive: true, isPublished: true },
      select: { id: true, stockQuantity: true },
    });
    if (!product) return { error: 'PRODUCT_NOT_FOUND' as const };

    const stock = Number(product.stockQuantity);
    if (stock <= 0) return { error: 'OUT_OF_STOCK' as const };

    // CAT-H3 — this stock read is intentionally an ADVISORY cap, NOT a
    // reservation. It is a plain read (no FOR UPDATE) so two concurrent carts
    // can both pass it; we do NOT decrement or hold stock here. The single
    // authority for availability is the confirm-time ledger decrement, which
    // runs under SELECT … FOR UPDATE and rejects an over-draw atomically. The
    // cap only trims an obviously-impossible line for nicer UX; client copy
    // must not promise the units are held. The `capped` flag below tells the
    // client we trimmed the request so it can show "only N available".
    const capped = Math.min(quantity, stock, MAX_LINE_QUANTITY);

    // Phase E v1 — variantId stays null on the cart line for now; the
    // customer app sets it on the new add-with-variant endpoint that
    // lands in v2. The (userId, productId, variantId) unique key
    // treats NULL as distinct in Postgres, so the explicit findFirst
    // + create/update pair is safer than upsert here (Prisma's
    // upsert.where can't carry a NULL on a unique-tuple key).
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

  /// Merge a guest cart from the client into the server cart. Each
  /// incoming line is upserted: if the user already has the product
  /// in their server cart, the quantities are summed (capped by stock
  /// + line limit); otherwise the line is created. Used by the
  /// customer app on the first login after the user added items as a
  /// guest. Idempotent so a network-retry can't double-merge.
  async merge(
    userId: number,
    items: { productId: number; quantity: number }[],
  ) {
    if (items.length === 0) return await this.list(userId);

    const ids = Array.from(new Set(items.map((i) => i.productId)));
    const products = await prisma.product.findMany({
      where: { id: { in: ids }, isActive: true, isPublished: true },
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

    // Coalesce duplicate productIds in the incoming payload before we
    // hit the DB so two "set qty=3" entries don't collapse to one.
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
      // Phase E v1 — merge into the variantId=null line; per-variant
      // merging lands in v2 alongside the cart-with-variant endpoint.
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

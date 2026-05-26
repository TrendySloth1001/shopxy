import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Customer-facing coupon module. Owns the validation + redemption
/// flow; coupon creation (merchant + platform admin tooling) lives in
/// a separate module surface — out of scope for the customer-side
/// roadmap that drove Phase 4.
///
/// All amounts are rupees. Two decimal places everywhere — no integer-
/// paise representation because the rest of the schema is decimal.

export type DiscountType = 'PERCENT' | 'FLAT';

export interface CouponContext {
  /// Cart subtotal (sum of item totals) BEFORE delivery, BEFORE this
  /// coupon's discount.
  subtotal: number;
  /// Shop ids touched by the cart — required because shop-scoped
  /// coupons only redeem when the cart includes at least one item
  /// from that shop.
  shopIds: number[];
}

export interface ValidatedCoupon {
  id: number;
  code: string;
  title: string;
  description: string | null;
  discountType: DiscountType;
  /// Effective discount amount applied to this cart (post-cap, post-
  /// math). May be less than `coupon.discountValue` for PERCENT
  /// coupons hitting the maxDiscount ceiling.
  discount: number;
}

export type ValidateError =
  | 'NOT_FOUND'
  | 'INACTIVE'
  | 'NOT_STARTED'
  | 'EXPIRED'
  | 'MIN_ORDER_NOT_MET'
  | 'SHOP_NOT_IN_CART'
  | 'PER_USER_LIMIT_REACHED'
  | 'TOTAL_CAP_REACHED';

function canon(code: string): string {
  return code.trim().toUpperCase().slice(0, 40);
}

function computeDiscount(
  coupon: {
    discountType: string;
    discountValue: Prisma.Decimal;
    maxDiscount: Prisma.Decimal | null;
  },
  subtotal: number,
): number {
  const value = Number(coupon.discountValue);
  let discount = 0;
  if (coupon.discountType === 'PERCENT') {
    discount = (subtotal * value) / 100;
    if (coupon.maxDiscount != null) {
      const cap = Number(coupon.maxDiscount);
      if (discount > cap) discount = cap;
    }
  } else {
    discount = value;
  }
  // Never refund more than the cart itself.
  if (discount > subtotal) discount = subtotal;
  return round2(discount);
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export interface CouponWriteInput {
  code: string;
  title: string;
  description?: string | null;
  discountType: DiscountType;
  discountValue: number;
  maxDiscount?: number | null;
  minOrderAmount?: number;
  validFrom: Date;
  validUntil: Date;
  perUserLimit?: number;
  totalCap?: number;
  isActive?: boolean;
}

export class CouponsService {
  /// Customer-facing list — coupons that could *potentially* apply
  /// today. Returns platform-wide + shop-scoped rows. Filters out
  /// inactive / expired / globally-capped ones server-side so the
  /// "My coupons" page never shows a card the customer can't use.
  ///
  /// Per-user-limit is computed inline so the client knows up-front
  /// whether the card is redeemable or just "you've already used this".
  async listAvailableForUser(userId: number) {
    const now = new Date();
    const rows = await prisma.coupon.findMany({
      where: {
        isActive: true,
        validFrom: { lte: now },
        validUntil: { gte: now },
      },
      orderBy: [{ shopId: 'asc' }, { validUntil: 'asc' }],
      select: {
        id: true,
        code: true,
        title: true,
        description: true,
        discountType: true,
        discountValue: true,
        maxDiscount: true,
        minOrderAmount: true,
        validFrom: true,
        validUntil: true,
        perUserLimit: true,
        totalCap: true,
        totalRedemptions: true,
        shopId: true,
        shop: { select: { id: true, name: true, slug: true } },
      },
    });

    if (rows.length === 0) return [];

    // Single round-trip for the user's redemption counts across every
    // candidate. Keeps the per-user-limit gate cheap.
    const counts = await prisma.couponRedemption.groupBy({
      by: ['couponId'],
      where: { userId, couponId: { in: rows.map((r) => r.id) } },
      _count: { _all: true },
    });
    const usedByCoupon = new Map(counts.map((c) => [c.couponId, c._count._all]));

    return rows
      .filter((r) => r.totalCap === 0 || r.totalRedemptions < r.totalCap)
      .map((r) => {
        const used = usedByCoupon.get(r.id) ?? 0;
        const exhausted = r.perUserLimit > 0 && used >= r.perUserLimit;
        return {
          id: r.id,
          code: r.code,
          title: r.title,
          description: r.description,
          discountType: r.discountType as DiscountType,
          discountValue: Number(r.discountValue),
          maxDiscount: r.maxDiscount != null ? Number(r.maxDiscount) : null,
          minOrderAmount: Number(r.minOrderAmount),
          validFrom: r.validFrom,
          validUntil: r.validUntil,
          shop: r.shop,
          alreadyUsed: used,
          perUserLimit: r.perUserLimit,
          exhausted,
        };
      });
  }

  /// Preview path — given a code + cart context, returns the discount
  /// amount that would apply (or a reason code). Used by the checkout
  /// page to show a live "₹X off" line before the customer commits.
  async validate(opts: {
    userId: number;
    code: string;
    context: CouponContext;
  }): Promise<
    | { error: ValidateError }
    | { coupon: ValidatedCoupon }
  > {
    const code = canon(opts.code);
    if (code.length === 0) return { error: 'NOT_FOUND' };

    const row = await prisma.coupon.findUnique({
      where: { code },
      select: {
        id: true,
        code: true,
        title: true,
        description: true,
        discountType: true,
        discountValue: true,
        maxDiscount: true,
        minOrderAmount: true,
        validFrom: true,
        validUntil: true,
        isActive: true,
        perUserLimit: true,
        totalCap: true,
        totalRedemptions: true,
        shopId: true,
      },
    });
    if (!row) return { error: 'NOT_FOUND' };
    if (!row.isActive) return { error: 'INACTIVE' };
    const now = new Date();
    if (row.validFrom > now) return { error: 'NOT_STARTED' };
    if (row.validUntil < now) return { error: 'EXPIRED' };
    if (Number(row.minOrderAmount) > opts.context.subtotal) {
      return { error: 'MIN_ORDER_NOT_MET' };
    }
    if (row.shopId != null && !opts.context.shopIds.includes(row.shopId)) {
      return { error: 'SHOP_NOT_IN_CART' };
    }
    if (row.totalCap > 0 && row.totalRedemptions >= row.totalCap) {
      return { error: 'TOTAL_CAP_REACHED' };
    }
    if (row.perUserLimit > 0) {
      const used = await prisma.couponRedemption.count({
        where: { couponId: row.id, userId: opts.userId },
      });
      if (used >= row.perUserLimit) return { error: 'PER_USER_LIMIT_REACHED' };
    }
    const discount = computeDiscount(row, opts.context.subtotal);
    return {
      coupon: {
        id: row.id,
        code: row.code,
        title: row.title,
        description: row.description,
        discountType: row.discountType as DiscountType,
        discount,
      },
    };
  }

  /// Atomic redemption — called inside the order-creation transaction
  /// so the discount math, redemption row, and counter bump all
  /// commit together. Returns the discount amount actually applied
  /// (post-cap, post-min, post-shop-scope).
  ///
  /// Concurrency-safe: the totalCap check is an `updateMany` gated on
  /// `total_redemptions < total_cap`, so two parallel checkouts can't
  /// both squeeze past the same cap. Per-user limit is gated similarly
  /// via a count + unique key combo (customer_order_id is unique on
  /// CouponRedemption so a retry of the same checkout can't double-claim).
  async redeem(opts: {
    tx: Prisma.TransactionClient;
    userId: number;
    code: string;
    context: CouponContext;
    customerOrderId: number;
  }): Promise<
    | { error: ValidateError }
    | { discount: number; couponId: number }
  > {
    const code = canon(opts.code);
    if (code.length === 0) return { error: 'NOT_FOUND' };

    const row = await opts.tx.coupon.findUnique({
      where: { code },
      select: {
        id: true,
        discountType: true,
        discountValue: true,
        maxDiscount: true,
        minOrderAmount: true,
        validFrom: true,
        validUntil: true,
        isActive: true,
        perUserLimit: true,
        totalCap: true,
        shopId: true,
      },
    });
    if (!row) return { error: 'NOT_FOUND' };
    if (!row.isActive) return { error: 'INACTIVE' };
    const now = new Date();
    if (row.validFrom > now) return { error: 'NOT_STARTED' };
    if (row.validUntil < now) return { error: 'EXPIRED' };
    if (Number(row.minOrderAmount) > opts.context.subtotal) {
      return { error: 'MIN_ORDER_NOT_MET' };
    }
    if (row.shopId != null && !opts.context.shopIds.includes(row.shopId)) {
      return { error: 'SHOP_NOT_IN_CART' };
    }
    if (row.perUserLimit > 0) {
      const used = await opts.tx.couponRedemption.count({
        where: { couponId: row.id, userId: opts.userId },
      });
      if (used >= row.perUserLimit) return { error: 'PER_USER_LIMIT_REACHED' };
    }

    // Atomic counter bump for totalCap. `updateMany` lets us gate on
    // the current value in one round-trip; if the cap was already
    // reached the row count is 0 and we bail out before writing the
    // redemption row.
    if (row.totalCap > 0) {
      const claimed = await opts.tx.coupon.updateMany({
        where: { id: row.id, totalRedemptions: { lt: row.totalCap } },
        data: { totalRedemptions: { increment: 1 } },
      });
      if (claimed.count !== 1) return { error: 'TOTAL_CAP_REACHED' };
    } else {
      // No cap — still bump the counter so analytics can read it.
      await opts.tx.coupon.update({
        where: { id: row.id },
        data: { totalRedemptions: { increment: 1 } },
      });
    }

    const discount = computeDiscount(row, opts.context.subtotal);
    await opts.tx.couponRedemption.create({
      data: {
        couponId: row.id,
        userId: opts.userId,
        customerOrderId: opts.customerOrderId,
        discountAmount: discount,
      },
    });
    return { discount, couponId: row.id };
  }

  // ── Merchant (shop-scoped) admin surface ─────────────────────────
  //
  // Every write below is scoped to the caller's `shopId`. A merchant
  // can only mutate coupons attached to their own shop; platform-wide
  // coupons (shopId = NULL) are admin-only and out of scope here.

  async listForShop(shopId: number) {
    const rows = await prisma.coupon.findMany({
      where: { shopId },
      orderBy: [{ isActive: 'desc' }, { validUntil: 'desc' }],
      select: {
        id: true,
        code: true,
        title: true,
        description: true,
        discountType: true,
        discountValue: true,
        maxDiscount: true,
        minOrderAmount: true,
        validFrom: true,
        validUntil: true,
        perUserLimit: true,
        totalCap: true,
        totalRedemptions: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    return rows.map((r) => ({
      ...r,
      discountValue: Number(r.discountValue),
      maxDiscount: r.maxDiscount != null ? Number(r.maxDiscount) : null,
      minOrderAmount: Number(r.minOrderAmount),
    }));
  }

  async createForShop(
    shopId: number,
    input: CouponWriteInput,
  ): Promise<{ id: number } | { error: 'CODE_TAKEN' | 'BAD_DATES' | 'BAD_VALUE' }> {
    const code = canon(input.code);
    if (code.length === 0) return { error: 'BAD_VALUE' };
    if (input.validFrom >= input.validUntil) return { error: 'BAD_DATES' };
    if (!(input.discountValue > 0)) return { error: 'BAD_VALUE' };
    if (input.discountType === 'PERCENT' && input.discountValue > 100) {
      return { error: 'BAD_VALUE' };
    }
    try {
      const row = await prisma.coupon.create({
        data: {
          code,
          title: input.title,
          description: input.description ?? null,
          discountType: input.discountType,
          discountValue: input.discountValue,
          maxDiscount: input.maxDiscount ?? null,
          minOrderAmount: input.minOrderAmount ?? 0,
          validFrom: input.validFrom,
          validUntil: input.validUntil,
          perUserLimit: input.perUserLimit ?? 1,
          totalCap: input.totalCap ?? 0,
          isActive: input.isActive ?? true,
          shopId,
        },
        select: { id: true },
      });
      return { id: row.id };
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') return { error: 'CODE_TAKEN' };
      throw e;
    }
  }

  async updateForShop(
    shopId: number,
    id: number,
    patch: Partial<CouponWriteInput>,
  ): Promise<{ ok: true } | { error: 'NOT_FOUND' | 'BAD_DATES' | 'BAD_VALUE' }> {
    // Only allow renames if the new code is still unique within the
    // platform. Same scope as create.
    if (patch.code != null && canon(patch.code).length === 0) {
      return { error: 'BAD_VALUE' };
    }
    if (
      patch.validFrom &&
      patch.validUntil &&
      patch.validFrom >= patch.validUntil
    ) {
      return { error: 'BAD_DATES' };
    }
    if (patch.discountValue != null && !(patch.discountValue > 0)) {
      return { error: 'BAD_VALUE' };
    }
    const data: Prisma.CouponUpdateInput = {};
    if (patch.code != null) data.code = canon(patch.code);
    if (patch.title != null) data.title = patch.title;
    if (patch.description !== undefined) data.description = patch.description ?? null;
    if (patch.discountType != null) data.discountType = patch.discountType;
    if (patch.discountValue != null) data.discountValue = patch.discountValue;
    if (patch.maxDiscount !== undefined) data.maxDiscount = patch.maxDiscount ?? null;
    if (patch.minOrderAmount != null) data.minOrderAmount = patch.minOrderAmount;
    if (patch.validFrom != null) data.validFrom = patch.validFrom;
    if (patch.validUntil != null) data.validUntil = patch.validUntil;
    if (patch.perUserLimit != null) data.perUserLimit = patch.perUserLimit;
    if (patch.totalCap != null) data.totalCap = patch.totalCap;
    if (patch.isActive != null) data.isActive = patch.isActive;

    const claim = await prisma.coupon.updateMany({
      where: { id, shopId },
      data,
    });
    if (claim.count === 1) return { ok: true };
    return { error: 'NOT_FOUND' };
  }

  async deactivateForShop(
    shopId: number,
    id: number,
  ): Promise<{ ok: true } | { error: 'NOT_FOUND' }> {
    const claim = await prisma.coupon.updateMany({
      where: { id, shopId },
      data: { isActive: false },
    });
    return claim.count === 1 ? { ok: true } : { error: 'NOT_FOUND' };
  }
}

export const couponsService = new CouponsService();

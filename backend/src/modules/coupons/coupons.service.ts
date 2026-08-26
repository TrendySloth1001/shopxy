import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

export type DiscountType = 'PERCENT' | 'FLAT';

export interface CouponContext {
  subtotal: number;
  shopIds: number[];
}

export interface ValidatedCoupon {
  id: number;
  code: string;
  title: string;
  description: string | null;
  discountType: DiscountType;
  discount: number;
  discountValue: number;
  maxDiscountAmount: number | null;
  minOrderAmount: number;
  expiresAt: string;
}

export type ValidateError =
  | 'NOT_FOUND'
  | 'INACTIVE'
  | 'NOT_STARTED'
  | 'EXPIRED'
  | 'MIN_ORDER_NOT_MET'
  | 'SHOP_NOT_IN_CART'
  | 'PER_USER_LIMIT_REACHED'
  | 'TOTAL_CAP_REACHED'
  | 'NOT_FIRST_ORDER';

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
  const sub = new Prisma.Decimal(subtotal);
  let discount: Prisma.Decimal;
  if (coupon.discountType === 'PERCENT') {
    discount = sub.mul(coupon.discountValue).div(100);
    if (coupon.maxDiscount != null && discount.greaterThan(coupon.maxDiscount)) {
      discount = coupon.maxDiscount;
    }
  } else {
    discount = coupon.discountValue;
  }
  if (discount.greaterThan(sub)) discount = sub;
  return Number(discount.toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP).toString());
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
  isPublic?: boolean;
  firstOrderOnly?: boolean;
}

export class CouponsService {
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
        isPublic: true,
        firstOrderOnly: true,
        shopId: true,
        shop: { select: { id: true, name: true, slug: true } },
      },
    });

    if (rows.length === 0) return [];

    const counts = await prisma.couponRedemption.groupBy({
      by: ['couponId'],
      where: { userId, couponId: { in: rows.map((r) => r.id) } },
      _count: { _all: true },
    });
    const usedByCoupon = new Map(counts.map((c) => [c.couponId, c._count._all]));

    const priorOrders = await prisma.customerOrder.count({
      where: { customerUserId: userId },
    });
    const isFirstOrder = priorOrders === 0;

    return rows
      .filter((r) => r.totalCap === 0 || r.totalRedemptions < r.totalCap)
      .map((r) => {
        const used = usedByCoupon.get(r.id) ?? 0;
        const perUserExhausted = r.perUserLimit > 0 && used >= r.perUserLimit;
        const firstOrderBlocked = r.firstOrderOnly && !isFirstOrder;
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
          isPublic: r.isPublic,
          firstOrderOnly: r.firstOrderOnly,
          shop: r.shop,
          alreadyUsed: used,
          perUserLimit: r.perUserLimit,
          exhausted: perUserExhausted || firstOrderBlocked,
        };
      });
  }

  async pickBestPublicForCart(opts: {
    userId: number;
    subtotal: number;
    shopIds: number[];
  }): Promise<
    | { coupon: ValidatedCoupon & { firstOrderOnly: boolean } }
    | null
  > {
    const now = new Date();
    const rows = await prisma.coupon.findMany({
      where: {
        isActive: true,
        isPublic: true,
        validFrom: { lte: now },
        validUntil: { gte: now },
        OR: [
          { shopId: null },
          ...(opts.shopIds.length > 0
            ? [{ shopId: { in: opts.shopIds } }]
            : []),
        ],
      },
      select: {
        id: true,
        code: true,
        title: true,
        description: true,
        discountType: true,
        discountValue: true,
        maxDiscount: true,
        minOrderAmount: true,
        validUntil: true,
        perUserLimit: true,
        totalCap: true,
        totalRedemptions: true,
        firstOrderOnly: true,
      },
    });
    if (rows.length === 0) return null;

    const candidateIds = rows.map((r) => r.id);
    const [usedRows, priorOrders] = await Promise.all([
      prisma.couponRedemption.groupBy({
        by: ['couponId'],
        where: { userId: opts.userId, couponId: { in: candidateIds } },
        _count: { _all: true },
      }),
      prisma.customerOrder.count({
        where: { customerUserId: opts.userId },
      }),
    ]);
    const usedByCoupon = new Map(
      usedRows.map((c) => [c.couponId, c._count._all]),
    );
    const isFirstOrder = priorOrders === 0;

    let best:
      | (typeof rows)[number] & { discount: number }
      | null = null;
    for (const r of rows) {
      if (Number(r.minOrderAmount) > opts.subtotal) continue;
      if (r.totalCap > 0 && r.totalRedemptions >= r.totalCap) continue;
      const used = usedByCoupon.get(r.id) ?? 0;
      if (r.perUserLimit > 0 && used >= r.perUserLimit) continue;
      if (r.firstOrderOnly && !isFirstOrder) continue;
      const discount = computeDiscount(r, opts.subtotal);
      if (discount <= 0) continue;
      if (
        best == null ||
        discount > best.discount ||
        (discount === best.discount && r.validUntil < best.validUntil)
      ) {
        best = { ...r, discount };
      }
    }
    if (best == null) return null;
    return {
      coupon: {
        id: best.id,
        code: best.code,
        title: best.title,
        description: best.description,
        discountType: best.discountType as DiscountType,
        discount: best.discount,
        discountValue: Number(best.discountValue),
        maxDiscountAmount: best.maxDiscount != null ? Number(best.maxDiscount) : null,
        minOrderAmount: Number(best.minOrderAmount),
        expiresAt: best.validUntil.toISOString(),
        firstOrderOnly: best.firstOrderOnly,
      },
    };
  }

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
        firstOrderOnly: true,
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
    if (row.firstOrderOnly) {
      const priorOrders = await prisma.customerOrder.count({
        where: { customerUserId: opts.userId },
      });
      if (priorOrders > 0) return { error: 'NOT_FIRST_ORDER' };
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
        discountValue: Number(row.discountValue),
        maxDiscountAmount: row.maxDiscount != null ? Number(row.maxDiscount) : null,
        minOrderAmount: Number(row.minOrderAmount),
        expiresAt: row.validUntil.toISOString(),
      },
    };
  }

  async redeem(opts: {
    tx: Prisma.TransactionClient;
    userId: number;
    code: string;
    context: CouponContext;
    customerOrderId: number;
  }): Promise<
    | { error: ValidateError }
    | { discount: number; couponId: number; couponShopId: number | null }
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
        firstOrderOnly: true,
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
    if (row.perUserLimit > 0 || row.firstOrderOnly) {
      await opts.tx.$executeRaw`SELECT pg_advisory_xact_lock(${row.id}, ${opts.userId})`;
    }
    if (row.perUserLimit > 0) {
      const used = await opts.tx.couponRedemption.count({
        where: { couponId: row.id, userId: opts.userId },
      });
      if (used >= row.perUserLimit) return { error: 'PER_USER_LIMIT_REACHED' };
    }
    if (row.firstOrderOnly) {
      const priorOrders = await opts.tx.customerOrder.count({
        where: {
          customerUserId: opts.userId,
          id: { not: opts.customerOrderId },
        },
      });
      if (priorOrders > 0) return { error: 'NOT_FIRST_ORDER' };
    }

    if (row.totalCap > 0) {
      const claimed = await opts.tx.coupon.updateMany({
        where: { id: row.id, totalRedemptions: { lt: row.totalCap } },
        data: { totalRedemptions: { increment: 1 } },
      });
      if (claimed.count !== 1) return { error: 'TOTAL_CAP_REACHED' };
    } else {
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
    return { discount, couponId: row.id, couponShopId: row.shopId ?? null };
  }

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
        isPublic: true,
        firstOrderOnly: true,
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

  async getForShop(shopId: number, id: number) {
    const r = await prisma.coupon.findFirst({
      where: { id, shopId },
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
        isPublic: true,
        firstOrderOnly: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!r) return null;
    return {
      ...r,
      discountValue: Number(r.discountValue),
      maxDiscount: r.maxDiscount != null ? Number(r.maxDiscount) : null,
      minOrderAmount: Number(r.minOrderAmount),
    };
  }

  async redemptionsForShop(shopId: number, couponId: number, limit = 50) {
    const owns = await prisma.coupon.findFirst({
      where: { id: couponId, shopId },
      select: { id: true },
    });
    if (!owns) return null;
    const rows = await prisma.couponRedemption.findMany({
      where: { couponId },
      orderBy: { redeemedAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 200),
      select: {
        id: true,
        discountAmount: true,
        redeemedAt: true,
        customerOrderId: true,
        user: { select: { id: true, name: true, email: true } },
      },
    });
    return rows.map((r) => ({
      id: r.id,
      discountAmount: Number(r.discountAmount),
      redeemedAt: r.redeemedAt,
      orderId: r.customerOrderId,
      user: r.user,
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
          isPublic: input.isPublic ?? false,
          firstOrderOnly: input.firstOrderOnly ?? false,
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
    if (patch.isPublic != null) data.isPublic = patch.isPublic;
    if (patch.firstOrderOnly != null) data.firstOrderOnly = patch.firstOrderOnly;
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

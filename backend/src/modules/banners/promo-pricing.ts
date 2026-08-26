import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { round2 } from '../../shared/numbering/decimal.js';

export type DiscountType = 'PERCENT' | 'AMOUNT';

export const MAX_PERCENT = 90;

export function clampDiscountValue(
  type: DiscountType,
  raw: number,
  sellingPrice: number,
): number {
  if (!Number.isFinite(raw) || raw <= 0) return 0;
  if (type === 'PERCENT') {
    return round2(Math.min(MAX_PERCENT, raw));
  }
  const ceiling = Math.max(0, round2(sellingPrice - 0.01));
  return round2(Math.min(ceiling, raw));
}

export function discountPerUnit(
  type: DiscountType,
  value: number,
  sellingPrice: number,
): number {
  if (value <= 0 || sellingPrice <= 0) return 0;
  if (type === 'PERCENT') return round2((sellingPrice * Math.min(MAX_PERCENT, value)) / 100);
  return round2(Math.min(value, Math.max(0, sellingPrice - 0.01)));
}

export function lineDiscount(
  type: DiscountType,
  value: number,
  unitPrice: number,
  qty: number,
): number {
  const perUnit = discountPerUnit(type, value, unitPrice);
  const ceiling = Math.max(0, round2(unitPrice * qty - 0.01));
  return round2(Math.min(perUnit * qty, ceiling));
}

export interface ResolvedPromo {
  type: DiscountType;
  value: number;
  perUnit: number;
  bannerId: number;
}

export async function resolveActiveProductPromos(
  shopId: number | null,
  productIds: number[],
  tx?: Prisma.TransactionClient,
): Promise<Map<number, ResolvedPromo>> {
  const out = new Map<number, ResolvedPromo>();
  if (productIds.length === 0) return out;

  const db = tx ?? prisma;
  const now = new Date();
  const rows = await db.bannerProduct.findMany({
    where: {
      productId: { in: productIds },
      banner: {
        ...(shopId != null ? { shopId } : {}),
        isActive: true,
        AND: [
          { OR: [{ startAt: null }, { startAt: { lte: now } }] },
          { OR: [{ endAt: null }, { endAt: { gte: now } }] },
        ],
      },
    },
    select: {
      bannerId: true,
      productId: true,
      discountType: true,
      discountValue: true,
      product: { select: { sellingPrice: true } },
    },
  });

  for (const r of rows) {
    const value = Number(r.discountValue);
    if (value <= 0) continue;
    const selling = Number(r.product.sellingPrice);
    const perUnit = discountPerUnit(r.discountType, value, selling);
    if (perUnit <= 0) continue;
    const prev = out.get(r.productId);
    if (!prev || perUnit > prev.perUnit) {
      out.set(r.productId, { type: r.discountType, value, perUnit, bannerId: r.bannerId });
    }
  }
  return out;
}

export function lineDiscountDecimal(
  type: DiscountType,
  value: number,
  unitPrice: Prisma.Decimal | number,
  qty: Prisma.Decimal | number,
): number {
  return lineDiscount(type, value, Number(unitPrice), Number(qty));
}

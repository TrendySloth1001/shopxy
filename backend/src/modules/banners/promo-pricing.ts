import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { round2 } from '../../shared/numbering/decimal.js';

/// Shared pricing rules for the BannerProduct promo surface. One module
/// owns clamping, per-line discount math, and active-promo lookup so the
/// merchant editor, customer order builder, and invoice generator can't
/// drift apart on what counts as a valid discount.

export type DiscountType = 'PERCENT' | 'AMOUNT';

/// Hard ceiling on a PERCENT row. 90% leaves at least 10% of revenue and
/// prevents accidental "100%" free-give bugs.
export const MAX_PERCENT = 90;

/// Clamp a merchant-typed number to a safe stored value.
///   - NaN / non-finite / negative → 0
///   - PERCENT clamped to [0, MAX_PERCENT]
///   - AMOUNT clamped to [0, sellingPrice - 0.01] so the line stays positive
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

/// Per-unit rupee discount this promo grants at the given sellingPrice.
export function discountPerUnit(
  type: DiscountType,
  value: number,
  sellingPrice: number,
): number {
  if (value <= 0 || sellingPrice <= 0) return 0;
  if (type === 'PERCENT') return round2((sellingPrice * value) / 100);
  return round2(Math.min(value, Math.max(0, sellingPrice - 0.01)));
}

/// Total rupee discount for an invoice/order line, bounded so the line
/// can't go negative (defense in depth).
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
  /// Banner that supplied this promo — handy for audit/annotations.
  bannerId: number;
}

/// Best active banner promo per product. `shopId` is optional — pass it
/// to restrict promos to a single merchant (the invoice case); omit it
/// for cross-shop reads (the customer cart spans many shops).
///
/// Returns a map keyed by productId; products with no active promo are
/// absent (callers default to no discount). "Active" = banner is on AND
/// inside its schedule window.
export async function resolveActiveProductPromos(
  shopId: number | null,
  productIds: number[],
): Promise<Map<number, ResolvedPromo>> {
  const out = new Map<number, ResolvedPromo>();
  if (productIds.length === 0) return out;

  const now = new Date();
  const rows = await prisma.bannerProduct.findMany({
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

/// Decimal-typed thin wrapper for callers already holding Prisma Decimals.
export function lineDiscountDecimal(
  type: DiscountType,
  value: number,
  unitPrice: Prisma.Decimal | number,
  qty: Prisma.Decimal | number,
): number {
  return lineDiscount(type, value, Number(unitPrice), Number(qty));
}

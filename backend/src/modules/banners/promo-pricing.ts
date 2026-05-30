import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { round2 } from '../../shared/numbering/decimal.js';

/// Shared pricing rules for the BannerProduct carousel-promo surface.
/// One module owns clamping, per-line discount math, and active-promo
/// lookup so the merchant editor, customer order builder, and invoice
/// generator can't drift apart on what counts as a valid discount.

export type DiscountType = 'PERCENT' | 'AMOUNT';

/// Hard ceiling on a PERCENT row. 90% leaves at least 10% of revenue —
/// matches the existing ad-hoc clamp the legacy `discountPct: Int`
/// column used, and prevents accidental "100%" free-give bugs.
export const MAX_PERCENT = 90;

/// Clamp a merchant-typed number to a safe stored value. Accepts the
/// raw input (could be NaN, negative, oversized, fractional percent) +
/// the product's current sellingPrice for AMOUNT bounds, returns the
/// value to persist. Always returns a finite non-negative number.
///
/// Rules:
///   - NaN / non-finite / negative → 0
///   - PERCENT clamped to [0, MAX_PERCENT]
///   - AMOUNT clamped to [0, sellingPrice - 0.01] so the line can never
///     end up at or below zero (we still want a positive taxable value)
export function clampDiscountValue(
  type: DiscountType,
  raw: number,
  sellingPrice: number,
): number {
  if (!Number.isFinite(raw) || raw <= 0) return 0;
  if (type === 'PERCENT') {
    return round2(Math.min(MAX_PERCENT, raw));
  }
  // AMOUNT
  const ceiling = Math.max(0, round2(sellingPrice - 0.01));
  return round2(Math.min(ceiling, raw));
}

/// Per-unit rupee discount this promo grants at the given sellingPrice.
/// Used to rank promos when a product appears in multiple slides.
export function discountPerUnit(
  type: DiscountType,
  value: number,
  sellingPrice: number,
): number {
  if (value <= 0 || sellingPrice <= 0) return 0;
  if (type === 'PERCENT') return round2((sellingPrice * value) / 100);
  return round2(Math.min(value, Math.max(0, sellingPrice - 0.01)));
}

/// Total rupee discount for an invoice/order line. Bounded so the line
/// can't go negative even if upstream callers forget to clamp the
/// discount on write (defense in depth).
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
  /// Per-unit rupee discount at lookup time. Cached so callers don't
  /// re-run discountPerUnit when ranking or applying.
  perUnit: number;
  /// Slide that supplied this promo — handy for audit logging and
  /// future "promotion: Spring Sale" line annotations on invoices.
  slideId: number;
}

/// Best active carousel promo per product. `shopId` is optional —
/// pass it to restrict promos to a single merchant (the invoice case;
/// only the issuing shop's own promos affect their books). Omit it
/// for cross-shop reads (the customer cart spans many shops).
///
/// Returns a map keyed by productId. Products with no active promo are
/// absent from the map (callers should default to no discount, not 0).
///
/// "Active" = banner is on AND inside its schedule window. Each
/// BannerProduct row is implicitly tied to the banner's sponsorShopId
/// (validated on write), so we don't need a separate ownership filter
/// per product.
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
        ...(shopId != null ? { sponsorShopId: shopId } : {}),
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
      out.set(r.productId, {
        type: r.discountType,
        value,
        perUnit,
        slideId: r.bannerId,
      });
    }
  }
  return out;
}

/// Decimal-typed thin wrappers — handy when callers already hold Prisma
/// Decimals (invoice items, PR items) and want to stay in Decimal land.
export function lineDiscountDecimal(
  type: DiscountType,
  value: number,
  unitPrice: Prisma.Decimal | number,
  qty: Prisma.Decimal | number,
): number {
  return lineDiscount(type, value, Number(unitPrice), Number(qty));
}

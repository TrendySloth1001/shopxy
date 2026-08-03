import type { ProductPricingMode } from '@prisma/client';

export type { ProductPricingMode };

export interface ProductPricingInput {
  taxPercent: number;
  cessRate: number;
  pricingMode: ProductPricingMode;
}

export interface ResolvedProductPricing {
  taxPercent: number;
  cessRate: number;
  isPriceInclusive: boolean;
}

/// The single place that turns a product's stored pricing mode into what the
/// GST engine actually needs. NO_GST always wins over whatever taxPercent/
/// cessRate happen to still be on the row (belt-and-suspenders — the write
/// path in products.service.ts also normalizes these to 0, but a caller
/// reading a stale/hand-edited row must not be able to bill it).
export function resolveProductPricing(p: ProductPricingInput): ResolvedProductPricing {
  if (p.pricingMode === 'NO_GST') {
    return { taxPercent: 0, cessRate: 0, isPriceInclusive: false };
  }
  return {
    taxPercent: p.taxPercent,
    cessRate: p.cessRate,
    isPriceInclusive: p.pricingMode === 'TAX_INCLUSIVE',
  };
}

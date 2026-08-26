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

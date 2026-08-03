import { describe, it, expect } from 'vitest';
import { resolveProductPricing } from '../../src/modules/products/pricing.js';

describe('resolveProductPricing', () => {
  it('TAX_EXCLUSIVE passes taxPercent/cessRate through and is not inclusive', () => {
    expect(resolveProductPricing({ taxPercent: 18, cessRate: 5, pricingMode: 'TAX_EXCLUSIVE' })).toEqual({
      taxPercent: 18,
      cessRate: 5,
      isPriceInclusive: false,
    });
  });

  it('TAX_EXCLUSIVE with a zero rate stays zero, not exempt', () => {
    expect(resolveProductPricing({ taxPercent: 0, cessRate: 0, pricingMode: 'TAX_EXCLUSIVE' })).toEqual({
      taxPercent: 0,
      cessRate: 0,
      isPriceInclusive: false,
    });
  });

  it('TAX_INCLUSIVE passes taxPercent/cessRate through and flags inclusive', () => {
    expect(resolveProductPricing({ taxPercent: 12, cessRate: 0, pricingMode: 'TAX_INCLUSIVE' })).toEqual({
      taxPercent: 12,
      cessRate: 0,
      isPriceInclusive: true,
    });
  });

  it('NO_GST forces taxPercent and cessRate to 0 even when the row still carries nonzero values', () => {
    expect(resolveProductPricing({ taxPercent: 28, cessRate: 12, pricingMode: 'NO_GST' })).toEqual({
      taxPercent: 0,
      cessRate: 0,
      isPriceInclusive: false,
    });
  });

  it('NO_GST is never reported as inclusive', () => {
    expect(resolveProductPricing({ taxPercent: 0, cessRate: 0, pricingMode: 'NO_GST' }).isPriceInclusive).toBe(false);
  });
});

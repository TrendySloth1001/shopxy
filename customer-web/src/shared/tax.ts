/**
 * GST breakup helpers for the customer storefront.
 *
 * TAX CONVENTION: consumer/marketplace prices are **GST-inclusive** (Legal
 * Metrology MRP default; the PDP shows "inclusive of all taxes"). So a line's
 * `sellingPrice` already contains tax — to surface the statutory breakup the
 * consumer must see BEFORE placing the order (CP E-Commerce Rules r.4(3)), we
 * BACK OUT the tax from the inclusive amount:
 *
 *   taxable = inclusive × 100 / (100 + rate)
 *   tax     = inclusive − taxable
 *
 * This is a client-side preview derived from the cart line tax rates. The
 * backend remains authoritative for the actual order invoice; when the
 * cart/checkout API exposes a server-computed breakup, prefer that and drop
 * this derivation (tracked as a follow-up).
 */

export interface TaxLineInput {
  /** GST-inclusive amount for the line (qty × inclusive unit price). */
  inclusiveAmount: number;
  /** GST rate as a percent, e.g. 18 for 18%. */
  taxPercent: number;
}

export interface TaxBreakup {
  /** Net taxable value, ex-tax (sum of per-rate taxable values). */
  taxableValue: number;
  /** Total GST backed out of the inclusive amounts. */
  taxTotal: number;
  /** Per-rate rows for an itemised display, ascending by rate. */
  perRate: Array<{ rate: number; taxable: number; tax: number }>;
}

/**
 * Derive a GST breakup from GST-inclusive line amounts grouped by rate.
 *
 * Lines with a non-positive rate (0% / unknown) contribute their full amount
 * to the taxable value but add no tax — they still belong in the taxable base
 * the consumer sees.
 */
export function deriveInclusiveTaxBreakup(lines: TaxLineInput[]): TaxBreakup {
  const byRate = new Map<number, number>();
  for (const l of lines) {
    if (!Number.isFinite(l.inclusiveAmount) || l.inclusiveAmount <= 0) continue;
    const rate = Number.isFinite(l.taxPercent) && l.taxPercent > 0 ? l.taxPercent : 0;
    byRate.set(rate, (byRate.get(rate) ?? 0) + l.inclusiveAmount);
  }

  const perRate: TaxBreakup["perRate"] = [];
  let taxableValue = 0;
  let taxTotal = 0;
  for (const [rate, inclusive] of byRate) {
    const taxable = rate > 0 ? (inclusive * 100) / (100 + rate) : inclusive;
    const tax = inclusive - taxable;
    taxableValue += taxable;
    taxTotal += tax;
    if (rate > 0) perRate.push({ rate, taxable, tax });
  }
  perRate.sort((a, b) => a.rate - b.rate);

  return { taxableValue, taxTotal, perRate };
}

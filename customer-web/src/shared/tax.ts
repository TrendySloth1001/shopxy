export interface TaxLineInput {
  inclusiveAmount: number;
  taxPercent: number;
}

export interface TaxBreakup {
  taxableValue: number;
  taxTotal: number;
  perRate: Array<{ rate: number; taxable: number; tax: number }>;
}

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

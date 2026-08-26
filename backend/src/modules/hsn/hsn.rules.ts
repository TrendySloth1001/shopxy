import type { HsnRateRule } from './hsn.master.js';

const APPAREL: HsnRateRule = {
  kind: 'PRICE_THRESHOLD',
  threshold: 2500,
  atOrBelow: 5,
  above: 18,
  per: 'PIECE',
};
const FOOTWEAR: HsnRateRule = { ...APPAREL, per: 'PAIR' };

const HOTEL: HsnRateRule = {
  kind: 'PRICE_THRESHOLD',
  threshold: 7500,
  atOrBelow: 5,
  above: 18,
  per: 'UNIT_PER_DAY',
};

export const HSN_RATE_RULES: Record<string, HsnRateRule> = {
  '6103': APPAREL, '6104': APPAREL, '6105': APPAREL, '6106': APPAREL,
  '6107': APPAREL, '6108': APPAREL, '6109': APPAREL, '6110': APPAREL,
  '6111': APPAREL, '6115': APPAREL,
  '6201': APPAREL, '6203': APPAREL, '6204': APPAREL, '6205': APPAREL,
  '6206': APPAREL, '6209': APPAREL, '6211': APPAREL, '6214': APPAREL,
  '6217': APPAREL,
  '6301': APPAREL, '6302': APPAREL, '6303': APPAREL, '6307': APPAREL,
  '4203': APPAREL,
  '6401': FOOTWEAR, '6402': FOOTWEAR, '6403': FOOTWEAR,
  '6404': FOOTWEAR, '6405': FOOTWEAR,
  '996311': HOTEL,
};

export const HSN_RATE_NOTES: Record<string, string> = {
  '1001': 'Nil when sold loose/unbranded; 5% when pre-packaged and labelled.',
  '1006': 'Nil when sold loose/unbranded; 5% when pre-packaged and labelled.',
  '1101': 'Nil when sold loose/unbranded; 5% when pre-packaged and labelled.',
  '0713': 'Nil when sold loose/unbranded; 5% when pre-packaged and labelled.',
  '8703': 'Small cars (petrol ≤1200cc / diesel ≤1500cc, ≤4 m) are 18%; larger, luxury and SUVs are 40%.',
  '8711': 'Engine capacity ≤350cc is 18%; above 350cc is 40%.',
  '2202': 'Fruit-pulp and juice-based drinks under 2202 99 are 5% — use the sub-heading.',
  '3004': 'A notified list of life-saving drugs is nil-rated — check the drug before defaulting.',
  '4820': 'Exercise books and notebooks are nil; commercial registers and diaries are 18%.',
  '9404': 'Cotton quilts up to ₹2,500 per piece are 5%.',
  '7113': 'Making charges billed separately are 5%.',
  '996331': 'Standalone restaurants are 5% without ITC; those in hotels with room tariff above ₹7,500 are 18% with ITC.',
};

export function applyOverlay<T extends { code: string; rateRule?: HsnRateRule; rateNote?: string }>(
  entries: T[],
): T[] {
  return entries.map((entry) => {
    const rule = entry.rateRule ?? HSN_RATE_RULES[entry.code];
    const note = entry.rateNote ?? HSN_RATE_NOTES[entry.code];
    if (!rule && !note) return entry;
    return {
      ...entry,
      ...(rule ? { rateRule: rule } : {}),
      ...(note ? { rateNote: note } : {}),
    };
  });
}

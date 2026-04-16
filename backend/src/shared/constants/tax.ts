export const TAX_RATES = [0, 5, 12, 18, 28] as const;

export type TaxRate = (typeof TAX_RATES)[number];

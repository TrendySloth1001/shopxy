export const STOCK_TRANSACTION_TYPES = [
  'STOCK_IN',
  'STOCK_OUT',
  'ADJUSTMENT',
] as const;

export type StockTransactionType = (typeof STOCK_TRANSACTION_TYPES)[number];

export const PURCHASE_PRICE_MODES = [
  'KEEP_CURRENT',
  'USE_LATEST',
  'WEIGHTED_AVERAGE',
] as const;

export type PurchasePriceMode = (typeof PURCHASE_PRICE_MODES)[number];

export const STOCK_TRANSACTION_LABELS: Record<StockTransactionType, string> = {
  STOCK_IN: 'Stock In',
  STOCK_OUT: 'Stock Out',
  ADJUSTMENT: 'Adjustment',
};

export const PURCHASE_PRICE_MODE_LABELS: Record<PurchasePriceMode, string> = {
  KEEP_CURRENT: 'Keep Current Purchase Price',
  USE_LATEST: 'Use Latest Stock-In Price',
  WEIGHTED_AVERAGE: 'Weighted Average Cost',
};

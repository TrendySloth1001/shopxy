export const STOCK_TRANSACTION_TYPES = [
  'STOCK_IN',
  'STOCK_OUT',
  'ADJUSTMENT',
] as const;

export type StockTransactionType = (typeof STOCK_TRANSACTION_TYPES)[number];

export const STOCK_TRANSACTION_LABELS: Record<StockTransactionType, string> = {
  STOCK_IN: 'Stock In',
  STOCK_OUT: 'Stock Out',
  ADJUSTMENT: 'Adjustment',
};

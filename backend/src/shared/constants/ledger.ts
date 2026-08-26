export const LEDGER_DIRECTIONS = ['IN', 'OUT'] as const;
export type LedgerDirection = (typeof LEDGER_DIRECTIONS)[number];

export const LEDGER_SOURCE_TYPES = [
  'MANUAL',
  'INVOICE',
  'CHALLAN',
  'ADJUSTMENT',
  'OPENING',
  'RETURN',
] as const;
export type LedgerSourceType = (typeof LEDGER_SOURCE_TYPES)[number];

export const LEDGER_REASON_CODES = [
  'SALE',
  'PURCHASE',
  'OPENING',
  'DAMAGE',
  'EXPIRED',
  'SHRINKAGE',
  'RECOUNT',
  'RETURN_IN',
  'RETURN_OUT',
] as const;
export type LedgerReasonCode = (typeof LEDGER_REASON_CODES)[number];

export const LEDGER_REASON_LABELS: Record<LedgerReasonCode, string> = {
  SALE: 'Sale',
  PURCHASE: 'Purchase',
  OPENING: 'Opening balance',
  DAMAGE: 'Damaged',
  EXPIRED: 'Expired',
  SHRINKAGE: 'Shrinkage',
  RECOUNT: 'Recount correction',
  RETURN_IN: 'Customer return',
  RETURN_OUT: 'Return to vendor',
};

export const IN_REASON_CODES: ReadonlySet<LedgerReasonCode> = new Set([
  'PURCHASE',
  'OPENING',
  'RETURN_IN',
  'RECOUNT',
]);

export const OUT_REASON_CODES: ReadonlySet<LedgerReasonCode> = new Set([
  'SALE',
  'DAMAGE',
  'EXPIRED',
  'SHRINKAGE',
  'RETURN_OUT',
  'RECOUNT',
]);

export const MANUAL_OUT_REASONS: readonly LedgerReasonCode[] = [
  'SALE',
  'SHRINKAGE',
  'DAMAGE',
  'EXPIRED',
  'RETURN_OUT',
] as const;

export const ADJUSTMENT_REASONS: readonly LedgerReasonCode[] = [
  'DAMAGE',
  'EXPIRED',
  'SHRINKAGE',
  'RECOUNT',
  'OPENING',
] as const;

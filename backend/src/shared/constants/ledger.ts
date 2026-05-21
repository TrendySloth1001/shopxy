// Ledger / inventory movement vocabulary.
// These constants define the language every inventory event must speak.

export const LEDGER_DIRECTIONS = ['IN', 'OUT'] as const;
export type LedgerDirection = (typeof LEDGER_DIRECTIONS)[number];

export const LEDGER_SOURCE_TYPES = [
  'MANUAL',
  'INVOICE',
  'CHALLAN',
  'ADJUSTMENT',
  'OPENING',
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

/// Reason codes that move stock IN.
export const IN_REASON_CODES: ReadonlySet<LedgerReasonCode> = new Set([
  'PURCHASE',
  'OPENING',
  'RETURN_IN',
  'RECOUNT', // recount may be either direction; service decides via direction field
]);

/// Reason codes that move stock OUT.
export const OUT_REASON_CODES: ReadonlySet<LedgerReasonCode> = new Set([
  'SALE',
  'DAMAGE',
  'EXPIRED',
  'SHRINKAGE',
  'RETURN_OUT',
  'RECOUNT',
]);

/// Reason codes a user can pick when posting a stock-out from the
/// manual sheet (i.e. without going through an adjustment document).
export const MANUAL_OUT_REASONS: readonly LedgerReasonCode[] = [
  'SALE',
  'SHRINKAGE',
  'DAMAGE',
  'EXPIRED',
  'RETURN_OUT',
] as const;

/// Reason codes that may be selected when creating a StockAdjustment.
export const ADJUSTMENT_REASONS: readonly LedgerReasonCode[] = [
  'DAMAGE',
  'EXPIRED',
  'SHRINKAGE',
  'RECOUNT',
  'OPENING',
] as const;

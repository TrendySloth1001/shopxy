/** Rupee formatting shared by the ledger-heavy screens (vendors, parties). */

const inr0 = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

const inr2 = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/** "₹1,200" (no paise) — the default for balances/totals. */
export function formatINR(value: number): string {
  return inr0.format(value);
}

/** "₹1,200.50" — when paise matter (ledger rows). */
export function formatINR2(value: number): string {
  return inr2.format(value);
}

/**
 * Parse a free-text money input into a number, ignoring everything that isn't
 * part of the number itself — the ₹ sign, thousands separators, spaces and any
 * other stray characters a user might type or paste (e.g. "₹1,200.50" → 1200.5,
 * "₹100.00" → 100). Returns `null` when there's no parseable amount, so callers
 * show "—"/no variance instead of leaking `NaN`. Use this for every money text
 * field (counted cash, opening float, cash movements).
 */
export function parseAmount(raw: string): number | null {
  const cleaned = raw.replace(/[^0-9.]/g, "");
  if (cleaned === "" || cleaned === ".") return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

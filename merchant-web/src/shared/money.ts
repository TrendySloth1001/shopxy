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

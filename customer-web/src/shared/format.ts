/**
 * Shared money formatting for the customer web app.
 *
 * All rupee amounts come from the backend as numbers (or Decimal-parsed floats).
 * Use formatINR for standard display; formatINRCompact for tight spaces (badge
 * counts, chart axes). Both use en-IN grouping (1,50,000 — not 150,000) and the
 * ₹ symbol from Intl, matching the Flutter customer app's AppFormat.rupees.
 */

const inrWhole = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
  minimumFractionDigits: 0,
});

const inrDecimal = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 2,
  minimumFractionDigits: 2,
});

/**
 * Format a rupee amount with en-IN digit grouping and the ₹ symbol.
 *
 * - `decimals: 0` (default) → whole rupees, "₹13,990"
 * - `decimals: 2`           → paise precision, "₹13,990.50"
 *
 * Non-finite values → "₹0".
 */
export function formatINR(
  value: number,
  opts: { decimals?: 0 | 2 } = {},
): string {
  if (!Number.isFinite(value)) return "₹0";
  const n = opts.decimals === 2 ? value : Math.round(value);
  return opts.decimals === 2 ? inrDecimal.format(n) : inrWhole.format(n);
}

/**
 * Compact rupee label for tight spaces: badge overlays, chart tick labels, etc.
 * Rounds to the nearest integer and abbreviates large numbers.
 *
 * ⚠️ APPROXIMATE BY DESIGN — rounds and abbreviates (K/L/Cr). This is for
 * non-transactional labels ONLY (chart axes, summary badges). NEVER use it for
 * a money figure of record — a payable, charged amount, refund, invoice or
 * order total. For any exact amount use `formatINR(value, { decimals: 2 })`.
 * (CP E-Commerce Rules r.4(3) — the price shown must be the price charged.)
 *
 * Examples:
 *   999       → "₹999"
 *   1_000     → "₹1K"
 *   1_500     → "₹1.5K"
 *   1_00_000  → "₹1L"
 *   10_00_000 → "₹10L"
 *   1_00_00_000 → "₹1Cr"
 */
export function formatINRCompact(value: number): string {
  if (!Number.isFinite(value)) return "₹0";
  const n = Math.round(value);
  if (Math.abs(n) >= 1_00_00_000) {
    const cr = n / 1_00_00_000;
    return `₹${cr % 1 === 0 ? cr.toFixed(0) : cr.toFixed(1)}Cr`;
  }
  if (Math.abs(n) >= 1_00_000) {
    const l = n / 1_00_000;
    return `₹${l % 1 === 0 ? l.toFixed(0) : l.toFixed(1)}L`;
  }
  if (Math.abs(n) >= 1_000) {
    const k = n / 1_000;
    return `₹${k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)}K`;
  }
  return `₹${n.toLocaleString("en-IN")}`;
}

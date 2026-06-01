/**
 * Pure, provider-neutral helpers shared by every adapter. No Razorpay, no
 * domain. These are the "reusable public helper functions" — single-sourced
 * so two gateways never reimplement money conversion or signature checks.
 */
import crypto from 'crypto';

/**
 * Float-safe rupee → paise. `Math.round(0.615 * 100)` is 61 under IEEE-754
 * (0.615 * 100 = 61.4999…); rounding the fixed-string first avoids the artefact.
 * (Carried over from the prior implementation's G23 fix.)
 */
export function toMinorUnits(rupees: number): number {
  return Math.round(Number((rupees * 100).toFixed(2)));
}

export function fromMinorUnits(paise: number): number {
  return paise / 100;
}

/**
 * Split `totalMinor` (paise) across weighted `shares` so the parts sum back to
 * EXACTLY `totalMinor` — no paise created or lost to rounding. Floors each part,
 * then hands the leftover paise to the largest fractional remainders (ties
 * broken by index, so the result is deterministic). When every share is 0 it
 * falls back to an even split. Used to fan a captured order's amount out to its
 * per-shop Route transfers (keyed on each child's estimatedTotal).
 */
export function allocateProportional(shares: number[], totalMinor: number): number[] {
  const n = shares.length;
  if (n === 0) return [];
  if (totalMinor <= 0) return shares.map(() => 0);
  const sum = shares.reduce((a, b) => a + b, 0);
  // All-zero weights → even split; otherwise weight by share.
  const weights = sum > 0 ? shares : shares.map(() => 1);
  const wsum = sum > 0 ? sum : n;
  const exact = weights.map((w) => (w / wsum) * totalMinor);
  const out = exact.map((x) => Math.floor(x));
  let leftover = totalMinor - out.reduce((a, b) => a + b, 0);
  const byFrac = exact
    .map((x, i) => ({ i, frac: x - Math.floor(x) }))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  for (let k = 0; leftover > 0; k++, leftover--) out[byFrac[k % n].i] += 1;
  return out;
}

/**
 * Fold any positive allocation below `minMinor` into the largest entry, so no
 * part is a non-zero amount under the provider's minimum transfer (₹1 = 100
 * paise on Razorpay Route, which rejects sub-floor transfers). Preserves the
 * total exactly. Returns a new array; entries folded away become 0.
 */
export function foldBelowMinimum(alloc: number[], minMinor: number): number[] {
  const out = alloc.slice();
  if (out.length === 0) return out;
  let largest = 0;
  for (let i = 1; i < out.length; i++) if (out[i] > out[largest]) largest = i;
  for (let i = 0; i < out.length; i++) {
    if (i !== largest && out[i] > 0 && out[i] < minMinor) {
      out[largest] += out[i];
      out[i] = 0;
    }
  }
  return out;
}

/** HMAC-SHA256 hex digest. */
export function hmacSha256Hex(secret: string, body: string | Buffer): string {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

/**
 * Constant-time hex compare. Returns false (not throw) on malformed hex or
 * length mismatch, so callers can treat it as a plain boolean gate.
 */
export function timingSafeEqualHex(a: string, b: string): boolean {
  let ab: Buffer;
  let bb: Buffer;
  try {
    ab = Buffer.from(a, 'hex');
    bb = Buffer.from(b, 'hex');
  } catch {
    return false;
  }
  return ab.length === bb.length && crypto.timingSafeEqual(ab, bb);
}

/** First string value of a possibly-array Express header. */
export function headerValue(
  headers: Record<string, string | string[] | undefined>,
  name: string,
): string | undefined {
  const v = headers[name] ?? headers[name.toLowerCase()];
  return Array.isArray(v) ? v[0] : v;
}

import crypto from 'crypto';

export function toMinorUnits(rupees: number): number {
  return Math.round(Number((rupees * 100).toFixed(2)));
}

export function fromMinorUnits(paise: number): number {
  return paise / 100;
}

export function allocateProportional(shares: number[], totalMinor: number): number[] {
  const n = shares.length;
  if (n === 0) return [];
  if (totalMinor <= 0) return shares.map(() => 0);
  const sum = shares.reduce((a, b) => a + b, 0);
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

export function hmacSha256Hex(secret: string, body: string | Buffer): string {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

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

export function headerValue(
  headers: Record<string, string | string[] | undefined>,
  name: string,
): string | undefined {
  const v = headers[name] ?? headers[name.toLowerCase()];
  return Array.isArray(v) ? v[0] : v;
}

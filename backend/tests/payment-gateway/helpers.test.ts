import { describe, it, expect } from 'vitest';
import crypto from 'crypto';
import {
  toMinorUnits,
  fromMinorUnits,
  hmacSha256Hex,
  timingSafeEqualHex,
  headerValue,
  allocateProportional,
  foldBelowMinimum,
} from '../../src/modules/payment-gateway/helpers.js';

describe('toMinorUnits — float-safe rupee -> paise', () => {
  it('converts whole rupees', () => {
    expect(toMinorUnits(100)).toBe(10000);
  });

  it('converts a two-decimal value exactly', () => {
    expect(toMinorUnits(99.99)).toBe(9999);
  });

  it('avoids the IEEE-754 0.615 artefact (G23 fix)', () => {
    expect(toMinorUnits(0.615)).toBe(62);
  });

  it('handles zero', () => {
    expect(toMinorUnits(0)).toBe(0);
  });

  it('rounds at the paise boundary', () => {
    expect(toMinorUnits(1.005)).toBe(101);
  });

  it('handles larger amounts', () => {
    expect(toMinorUnits(12345.67)).toBe(1234567);
  });
});

describe('fromMinorUnits — paise -> rupees', () => {
  it('converts whole hundreds', () => {
    expect(fromMinorUnits(10000)).toBe(100);
  });

  it('converts with paise', () => {
    expect(fromMinorUnits(9999)).toBe(99.99);
  });

  it('handles zero', () => {
    expect(fromMinorUnits(0)).toBe(0);
  });

  it('round-trips with toMinorUnits', () => {
    expect(fromMinorUnits(toMinorUnits(250.5))).toBe(250.5);
  });
});

describe('hmacSha256Hex', () => {
  it('matches the canonical SHA-256 HMAC test vector', () => {
    expect(
      hmacSha256Hex('key', 'The quick brown fox jumps over the lazy dog'),
    ).toBe('f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8');
  });

  it('agrees with a direct crypto computation for a Buffer body', () => {
    const secret = 's3cr3t';
    const body = Buffer.from('payload-bytes');
    const expected = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');
    expect(hmacSha256Hex(secret, body)).toBe(expected);
  });

  it('produces a different digest for a different secret', () => {
    const a = hmacSha256Hex('secret-a', 'body');
    const b = hmacSha256Hex('secret-b', 'body');
    expect(a).not.toBe(b);
  });
});

describe('timingSafeEqualHex', () => {
  it('returns true for equal hex strings', () => {
    const h = hmacSha256Hex('key', 'body');
    expect(timingSafeEqualHex(h, h)).toBe(true);
  });

  it('returns false for different equal-length hex strings', () => {
    const a = hmacSha256Hex('key', 'body-a');
    const b = hmacSha256Hex('key', 'body-b');
    expect(timingSafeEqualHex(a, b)).toBe(false);
  });

  it('returns false on length mismatch', () => {
    expect(timingSafeEqualHex('abcd', 'abcdef')).toBe(false);
  });

  it('treats malformed (odd-length) hex as a length mismatch -> false', () => {
    expect(timingSafeEqualHex('abc', 'abcd')).toBe(false);
  });

  it('returns false when one side is empty and the other is not', () => {
    expect(timingSafeEqualHex('', 'ab')).toBe(false);
  });

  it('returns true for two empty strings (both decode to zero-length)', () => {
    expect(timingSafeEqualHex('', '')).toBe(true);
  });
});

describe('allocateProportional — split that sums EXACTLY to the total', () => {
  it('splits evenly when shares are equal', () => {
    expect(allocateProportional([100, 100], 10000)).toEqual([5000, 5000]);
  });

  it('distributes the rounding residue so parts always re-sum to the total', () => {
    const out = allocateProportional([1, 1, 1], 10000);
    expect(out.reduce((a, b) => a + b, 0)).toBe(10000);
    expect(out).toEqual([3334, 3333, 3333]);
  });

  it('weights by share size', () => {
    const out = allocateProportional([300, 100], 10000);
    expect(out).toEqual([7500, 2500]);
    expect(out.reduce((a, b) => a + b, 0)).toBe(10000);
  });

  it('never creates or loses a paisa across awkward ratios', () => {
    const out = allocateProportional([333, 333, 334, 1], 99999);
    expect(out.reduce((a, b) => a + b, 0)).toBe(99999);
  });

  it('falls back to an even split when every share is zero', () => {
    const out = allocateProportional([0, 0], 9999);
    expect(out.reduce((a, b) => a + b, 0)).toBe(9999);
    expect(out).toEqual([5000, 4999]);
  });

  it('returns zeros for a zero total', () => {
    expect(allocateProportional([5, 3], 0)).toEqual([0, 0]);
  });

  it('handles a single child taking the whole amount', () => {
    expect(allocateProportional([42], 7777)).toEqual([7777]);
  });
});

describe('foldBelowMinimum — no sub-₹1 transfer slice', () => {
  it('folds a sub-floor slice into the largest entry, preserving the total', () => {
    const out = foldBelowMinimum([9950, 50], 100);
    expect(out).toEqual([10000, 0]);
    expect(out.reduce((a, b) => a + b, 0)).toBe(10000);
  });

  it('leaves all-above-floor allocations untouched', () => {
    expect(foldBelowMinimum([5000, 5000], 100)).toEqual([5000, 5000]);
  });

  it('folds multiple sub-floor slices into the single largest', () => {
    const out = foldBelowMinimum([9900, 50, 50], 100);
    expect(out).toEqual([10000, 0, 0]);
    expect(out.reduce((a, b) => a + b, 0)).toBe(10000);
  });

  it('does not fold a zero (nothing to move)', () => {
    expect(foldBelowMinimum([10000, 0], 100)).toEqual([10000, 0]);
  });
});

describe('headerValue', () => {
  it('returns the first element of an array value', () => {
    const headers = { 'x-signature': ['sig-1', 'sig-2'] };
    expect(headerValue(headers, 'x-signature')).toBe('sig-1');
  });

  it('returns a plain string value', () => {
    const headers = { 'x-signature': 'sig' };
    expect(headerValue(headers, 'x-signature')).toBe('sig');
  });

  it('falls back to the lowercased key when the exact key is absent', () => {
    const headers = { 'x-signature': 'sig' };
    expect(headerValue(headers, 'X-Signature')).toBe('sig');
  });

  it('returns undefined for a missing header', () => {
    const headers = { 'x-signature': 'sig' };
    expect(headerValue(headers, 'x-nope')).toBeUndefined();
  });

  it('returns undefined for an explicitly undefined header', () => {
    const headers: Record<string, string | string[] | undefined> = {
      'x-signature': undefined,
    };
    expect(headerValue(headers, 'x-signature')).toBeUndefined();
  });
});

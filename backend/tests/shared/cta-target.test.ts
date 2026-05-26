import { describe, it, expect } from 'vitest';
import {
  isValidCtaTarget,
  parseCtaTarget,
  MAX_CTA_TARGET_LENGTH,
} from '../../src/shared/cta-target.js';

describe('cta-target — parser', () => {
  it('accepts category slugs', () => {
    expect(parseCtaTarget('category:fashion')).toEqual({
      kind: 'category',
      value: 'fashion',
    });
  });

  it('accepts product ids', () => {
    expect(parseCtaTarget('product:42')).toEqual({
      kind: 'product',
      value: '42',
    });
  });

  it('accepts http and https URLs', () => {
    expect(isValidCtaTarget('url:https://example.com/path')).toBe(true);
    expect(isValidCtaTarget('url:http://example.com')).toBe(true);
  });

  it('rejects javascript: URLs', () => {
    expect(isValidCtaTarget('url:javascript:alert(1)')).toBe(false);
  });

  it('rejects unknown kinds', () => {
    expect(parseCtaTarget('shop:abc')).toBeNull();
  });

  it('rejects empty values', () => {
    expect(parseCtaTarget('category:')).toBeNull();
    expect(parseCtaTarget('')).toBeNull();
  });

  it('rejects slugs with disallowed characters', () => {
    expect(parseCtaTarget('category:Fashion!')).toBeNull();
  });
});

describe('cta-target — ReDoS safety', () => {
  it('rejects inputs longer than MAX_CTA_TARGET_LENGTH', () => {
    const tooLong = 'a'.repeat(MAX_CTA_TARGET_LENGTH + 1);
    expect(parseCtaTarget(tooLong)).toBeNull();
  });

  // Stress: 2048 chars of a single letter has no ":" so it bails at the
  // length / indexOf check. The whole validator must finish in well
  // under 10ms — if a future change makes a regex backtrack on this
  // shape, the assertion will flag it.
  it('isValidCtaTarget completes <10ms on a 2048-char input', () => {
    const big = 'a'.repeat(2048);
    const start = process.hrtime.bigint();
    isValidCtaTarget(big);
    const elapsedMs = Number(process.hrtime.bigint() - start) / 1_000_000;
    expect(elapsedMs).toBeLessThan(10);
  });

  it('isValidCtaTarget completes <10ms on a 2048-char colon-prefixed input', () => {
    // Worst case shape: passes the indexOf guard, then hits the slug
    // regex with 2046 characters. The regex is anchored + bounded, so
    // it should reject in O(1)-ish time.
    const big = 'category:' + 'a'.repeat(2048 - 'category:'.length);
    const start = process.hrtime.bigint();
    isValidCtaTarget(big);
    const elapsedMs = Number(process.hrtime.bigint() - start) / 1_000_000;
    expect(elapsedMs).toBeLessThan(10);
  });
});

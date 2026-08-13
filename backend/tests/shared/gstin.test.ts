import { describe, it, expect } from 'vitest';
import {
  GSTIN_REGEX,
  gstinCheckDigit,
  isValidGstin,
} from '../../src/shared/validation/indian.js';

/// The 15th character is a mod-36 check digit over the first 14. These two are
/// the GSTINs used as worked examples in GSTN's own documentation, so they are
/// the fixture that proves the algorithm rather than the algorithm proving
/// itself: both round-trip only if the weighting and base-36 digit sum match
/// the published spec.
const REAL_GSTINS = ['27AAPFU0939F1ZV', '19AAACI1681G1ZM'];

describe('gstinCheckDigit', () => {
  it('reproduces the published check digit', () => {
    for (const gstin of REAL_GSTINS) {
      expect(gstinCheckDigit(gstin.slice(0, 14))).toBe(gstin[14]);
    }
  });

  it('returns null for anything that is not 14 characters', () => {
    expect(gstinCheckDigit('27AAPFU0939F1')).toBeNull();
    expect(gstinCheckDigit('27AAPFU0939F1ZV')).toBeNull();
    expect(gstinCheckDigit('')).toBeNull();
  });

  it('returns null on a character outside the base-36 alphabet', () => {
    expect(gstinCheckDigit('27AAPFU0939F1-')).toBeNull();
    expect(gstinCheckDigit('27aapfu0939f1z')).toBeNull();
  });
});

describe('isValidGstin', () => {
  it('accepts a correctly checksummed GSTIN', () => {
    for (const gstin of REAL_GSTINS) {
      expect(isValidGstin(gstin)).toBe(true);
    }
  });

  it('accepts lower case and surrounding whitespace', () => {
    expect(isValidGstin('  27aapfu0939f1zv ')).toBe(true);
  });

  it('rejects a single-character typo the shape check lets through', () => {
    // One digit changed. GSTIN_REGEX still matches, which is exactly why the
    // checksum has to run: this is the failure mode that reaches a filed
    // return as the buyer's credit denied and the seller's GSTR-1 mismatched.
    const typo = '27AAPFU0939F1ZX';
    expect(GSTIN_REGEX.test(typo)).toBe(true);
    expect(isValidGstin(typo)).toBe(false);
  });

  it('rejects a two-digit prefix that is not a real state code', () => {
    // "99" is two digits but no state was ever notified under it, so the
    // place-of-supply derived from it would be meaningless.
    const badState = '99AAPFU0939F1ZV';
    expect(GSTIN_REGEX.test(badState)).toBe(true);
    expect(isValidGstin(badState)).toBe(false);
  });

  it('rejects malformed, empty and absent values', () => {
    expect(isValidGstin('27AAPFU0939F1')).toBe(false);
    expect(isValidGstin('NOT-A-GSTIN')).toBe(false);
    expect(isValidGstin('')).toBe(false);
    expect(isValidGstin(null)).toBe(false);
    expect(isValidGstin(undefined)).toBe(false);
  });
});

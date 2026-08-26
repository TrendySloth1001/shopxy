import { describe, it, expect } from 'vitest';
import {
  GSTIN_REGEX,
  gstinCheckDigit,
  isValidGstin,
} from '../../src/shared/validation/indian.js';

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
    const typo = '27AAPFU0939F1ZX';
    expect(GSTIN_REGEX.test(typo)).toBe(true);
    expect(isValidGstin(typo)).toBe(false);
  });

  it('rejects a two-digit prefix that is not a real state code', () => {
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

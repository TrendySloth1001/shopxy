import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { Prisma } from '@prisma/client';
import {
  encodeId,
  decodeId,
  idsEnabled,
  encodeIdsDeep,
} from '../../src/shared/ids/publicId.js';
import { zPublicId } from '../../src/shared/ids/zPublicId.js';

const ORIGINAL = process.env.PUBLIC_IDS;
function setFlag(on: boolean) {
  process.env.PUBLIC_IDS = on ? 'true' : 'false';
}
beforeEach(() => setFlag(false));
afterEach(() => {
  if (ORIGINAL === undefined) delete process.env.PUBLIC_IDS;
  else process.env.PUBLIC_IDS = ORIGINAL;
});

describe('publicId codec — flag OFF (default, expand/contract landing)', () => {
  it('is a no-op: encodeId returns the raw number', () => {
    expect(idsEnabled()).toBe(false);
    expect(encodeId(1)).toBe(1);
    expect(encodeId(999999)).toBe(999999);
  });

  it('decodeId still accepts legacy integer ids', () => {
    expect(decodeId('1')).toBe(1);
    expect(decodeId('42')).toBe(42);
  });
});

describe('publicId codec — flag ON', () => {
  beforeEach(() => setFlag(true));

  it('encodes to an opaque, non-numeric, padded token', () => {
    const t = encodeId(1);
    expect(typeof t).toBe('string');
    expect(t).not.toBe('1');
    expect(String(t)).not.toMatch(/^\d+$/);
    expect(String(t).length).toBeGreaterThanOrEqual(8);
  });

  it('round-trips every id back to itself', () => {
    for (const n of [1, 2, 3, 50, 12345, 999_999_999]) {
      const token = encodeId(n);
      expect(typeof token).toBe('string');
      expect(decodeId(String(token))).toBe(n);
    }
  });

  it('does not leak the sequence: adjacent ids give unrelated tokens', () => {
    const a = String(encodeId(1));
    const b = String(encodeId(2));
    const c = String(encodeId(3));
    expect(new Set([a, b, c]).size).toBe(3);
    expect(a.slice(0, 4)).not.toBe(b.slice(0, 4));
  });

  it('remains dual-mode: legacy integer ids still decode', () => {
    expect(decodeId('7')).toBe(7);
  });
});

describe('publicId codec — decode is hostile-input safe (both modes)', () => {
  for (const on of [false, true]) {
    describe(on ? 'flag ON' : 'flag OFF', () => {
      beforeEach(() => setFlag(on));

      it('rejects empty / null / whitespace', () => {
        expect(decodeId('')).toBeNull();
        expect(decodeId('   ')).toBeNull();
        expect(decodeId(null)).toBeNull();
        expect(decodeId(undefined)).toBeNull();
      });

      it('rejects non-positive and non-integer numeric strings', () => {
        expect(decodeId('0')).toBeNull();
        expect(decodeId('-5')).toBeNull();
        expect(decodeId('3.14')).toBeNull();
        expect(decodeId('1e3')).toBeNull();
      });

      it('rejects forged / garbage tokens via the round-trip guard', () => {
        expect(decodeId('!!!!!!!!')).toBeNull();
        expect(decodeId('not-a-token')).toBeNull();
        expect(decodeId('        x')).toBeNull();
      });
    });
  }
});

describe('encodeIdsDeep — response tokeniser', () => {
  it('is identity when flag OFF (no clone, no cost)', () => {
    const payload = { id: 1, categoryId: 2, name: 'x' };
    expect(encodeIdsDeep(payload)).toBe(payload);
  });

  describe('flag ON', () => {
    beforeEach(() => setFlag(true));

    it('tokenises id and every *Id field, at any depth', () => {
      const out = encodeIdsDeep({
        id: 1,
        categoryId: 2,
        shopId: 3,
        name: 'Laptop',
        variants: [{ id: 10, sku: 'A' }, { id: 11, sku: 'B' }],
        category: { id: 2, name: 'Laptops' },
        images: [{ id: 100, productId: 1, url: '/x.png' }],
      });
      expect(typeof out.id).toBe('string');
      expect(typeof out.categoryId).toBe('string');
      expect(typeof out.shopId).toBe('string');
      expect(out.name).toBe('Laptop');
      expect(typeof out.variants[0].id).toBe('string');
      expect(typeof out.category.id).toBe('string');
      expect(typeof out.images[0].id).toBe('string');
      expect(typeof out.images[0].productId).toBe('string');
      expect(decodeId(String(out.variants[1].id))).toBe(11);
      expect(decodeId(String(out.images[0].productId))).toBe(1);
    });

    it('NEVER corrupts money (Prisma.Decimal) or Dates', () => {
      const created = new Date('2026-01-02T03:04:05Z');
      const out = encodeIdsDeep({
        id: 5,
        sellingPrice: new Prisma.Decimal('1999.50'),
        createdAt: created,
      });
      expect(typeof out.id).toBe('string');
      expect(out.sellingPrice).toBeInstanceOf(Prisma.Decimal);
      expect(out.sellingPrice.toString()).toBe('1999.5');
      expect(out.createdAt).toBe(created);
    });

    it('leaves string *Id fields alone (e.g. external gateway ids)', () => {
      const out = encodeIdsDeep({ id: 1, razorpayOrderId: 'order_abc123' });
      expect(typeof out.id).toBe('string');
      expect(out.razorpayOrderId).toBe('order_abc123');
    });
  });
});

describe('zPublicId — request-body decoder', () => {
  it('OFF: accepts a legacy numeric id (number or string)', () => {
    setFlag(false);
    expect(zPublicId.parse(5)).toBe(5);
    expect(zPublicId.parse('5')).toBe(5);
  });

  it('ON: accepts the opaque token AND a legacy numeric id (dual-mode)', () => {
    setFlag(true);
    const token = String(encodeId(42));
    expect(zPublicId.parse(token)).toBe(42);
    expect(zPublicId.parse('42')).toBe(42);
  });

  it('rejects garbage with a validation error', () => {
    setFlag(true);
    expect(zPublicId.safeParse('not-an-id').success).toBe(false);
    expect(zPublicId.safeParse('0').success).toBe(false);
  });
});

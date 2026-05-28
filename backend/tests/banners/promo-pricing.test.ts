import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import {
  clampDiscountValue,
  discountPerUnit,
  lineDiscount,
  resolveActiveProductPromos,
  MAX_PERCENT,
} from '../../src/modules/banners/promo-pricing.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

/// Pure-function tests for the clamp + line math. Don't touch the DB —
/// kept in this file so the next reader sees the whole promo surface
/// (math + lookup + invoice integration) in one place.
describe('promo-pricing — clamp + math', () => {
  it('rejects NaN, negatives, non-finite inputs', () => {
    expect(clampDiscountValue('PERCENT', NaN, 100)).toBe(0);
    expect(clampDiscountValue('PERCENT', -5, 100)).toBe(0);
    expect(clampDiscountValue('AMOUNT', Infinity, 100)).toBe(0);
    expect(clampDiscountValue('AMOUNT', -1, 100)).toBe(0);
  });

  it('clamps PERCENT to MAX_PERCENT', () => {
    expect(clampDiscountValue('PERCENT', 95, 100)).toBe(MAX_PERCENT);
    expect(clampDiscountValue('PERCENT', 50, 100)).toBe(50);
    expect(clampDiscountValue('PERCENT', 25.75, 100)).toBe(25.75);
  });

  it('clamps AMOUNT to sellingPrice - 0.01 so the line stays positive', () => {
    expect(clampDiscountValue('AMOUNT', 999, 100)).toBe(99.99);
    expect(clampDiscountValue('AMOUNT', 30, 100)).toBe(30);
    expect(clampDiscountValue('AMOUNT', 100, 100)).toBe(99.99);
    // sellingPrice 0 means no headroom — clamp to 0
    expect(clampDiscountValue('AMOUNT', 5, 0)).toBe(0);
  });

  it('discountPerUnit matches the two pricing modes', () => {
    expect(discountPerUnit('PERCENT', 25, 200)).toBe(50);
    expect(discountPerUnit('AMOUNT', 30, 200)).toBe(30);
    // AMOUNT > selling price safety: caps at sellingPrice - 0.01
    expect(discountPerUnit('AMOUNT', 999, 100)).toBe(99.99);
  });

  it('lineDiscount can never make the line non-positive', () => {
    // PERCENT 50% × 2 units × ₹100 = ₹100 saved, line stays positive (₹100)
    expect(lineDiscount('PERCENT', 50, 100, 2)).toBe(100);
    // Even a corrupted row with type=PERCENT value=300 only saves up to
    // (qty * unitPrice - 0.01).
    expect(lineDiscount('PERCENT', 300, 100, 2)).toBe(199.99);
    // AMOUNT ₹30/unit × 3 = ₹90
    expect(lineDiscount('AMOUNT', 30, 50, 3)).toBe(90);
  });
});

const PASSWORD = 'TestPassw0rd!';

describe('promo-pricing — resolver + invoice auto-fill', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('picks the largest per-unit discount across multiple slides', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, {
        mrp: 200,
        sellingPrice: 200,
      });
      // Slide A: 10% off  →  ₹20/unit
      // Slide B: ₹50 off  →  ₹50/unit  (winner)
      const a = await prisma.banner.create({
        data: {
          placement: 'HERO',
          sponsorShopId: ctx.shopId,
          title: 'A',
          imageUrl: '/img/a.webp',
          bgColor: '#FFFFFF',
          isActive: true,
        },
      });
      const b = await prisma.banner.create({
        data: {
          placement: 'HERO',
          sponsorShopId: ctx.shopId,
          title: 'B',
          imageUrl: '/img/b.webp',
          bgColor: '#FFFFFF',
          isActive: true,
        },
      });
      await prisma.bannerProduct.create({
        data: {
          bannerId: a.id,
          productId: product.id,
          discountType: 'PERCENT',
          discountValue: 10,
        },
      });
      await prisma.bannerProduct.create({
        data: {
          bannerId: b.id,
          productId: product.id,
          discountType: 'AMOUNT',
          discountValue: 50,
        },
      });

      const promos = await resolveActiveProductPromos(ctx.shopId, [product.id]);
      const promo = promos.get(product.id)!;
      expect(promo.type).toBe('AMOUNT');
      expect(promo.perUnit).toBe(50);
      expect(promo.slideId).toBe(b.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('ignores inactive and out-of-window banners', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 100,
      });
      const future = new Date(Date.now() + 24 * 60 * 60 * 1000);
      const past = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const off = await prisma.banner.create({
        data: {
          placement: 'HERO', sponsorShopId: ctx.shopId,
          title: 'off', imageUrl: '/x.webp', bgColor: '#FFFFFF',
          isActive: false,
        },
      });
      const futureBanner = await prisma.banner.create({
        data: {
          placement: 'HERO', sponsorShopId: ctx.shopId,
          title: 'future', imageUrl: '/x.webp', bgColor: '#FFFFFF',
          isActive: true, startAt: future,
        },
      });
      const expiredBanner = await prisma.banner.create({
        data: {
          placement: 'HERO', sponsorShopId: ctx.shopId,
          title: 'expired', imageUrl: '/x.webp', bgColor: '#FFFFFF',
          isActive: true, endAt: past,
        },
      });
      for (const b of [off, futureBanner, expiredBanner]) {
        await prisma.bannerProduct.create({
          data: {
            bannerId: b.id,
            productId: product.id,
            discountType: 'PERCENT',
            discountValue: 25,
          },
        });
      }
      const promos = await resolveActiveProductPromos(ctx.shopId, [product.id]);
      expect(promos.has(product.id)).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('auto-fills invoice line discount from active carousel promo', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 100,
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Buyer' },
      });
      const banner = await prisma.banner.create({
        data: {
          placement: 'HERO', sponsorShopId: ctx.shopId,
          title: 'Promo', imageUrl: '/p.webp', bgColor: '#FFFFFF', isActive: true,
        },
      });
      await prisma.bannerProduct.create({
        data: {
          bannerId: banner.id,
          productId: product.id,
          discountType: 'PERCENT',
          discountValue: 20,
        },
      });

      // Merchant DOESN'T type a discount — backend should auto-fill ₹20
      // (20% of ₹100 × 1 unit).
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 1, unitPrice: 100 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const line = result.invoice.items[0];
      expect(Number(line.discount)).toBe(20);
      expect(Number(line.taxableValue)).toBe(80);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('explicit merchant discount overrides the carousel promo', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 100,
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Buyer' },
      });
      const banner = await prisma.banner.create({
        data: {
          placement: 'HERO', sponsorShopId: ctx.shopId,
          title: 'Promo', imageUrl: '/p.webp', bgColor: '#FFFFFF', isActive: true,
        },
      });
      await prisma.bannerProduct.create({
        data: {
          bannerId: banner.id,
          productId: product.id,
          discountType: 'PERCENT',
          discountValue: 50,
        },
      });
      // Merchant types discount: 5 (less than the promo) — must win.
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [
          { productId: product.id, quantity: 1, unitPrice: 100, discount: 5 },
        ],
      });
      if ('error' in result) throw new Error('unexpected error');
      expect(Number(result.invoice.items[0].discount)).toBe(5);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});

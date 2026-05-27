import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  createTestProduct,
  cleanupTestUser,
} from '../helpers/setup.js';

const app = buildApp();

describe('home feed', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('GET /home/feed returns the documented shape without auth', async () => {
    const res = await request(app).get('/home/feed');
    expect(res.status).toBe(200);
    for (const key of [
      'heroBanners',
      'adStripBanners',
      'promoBanners',
      'curatedRailBanners',
      'flashDeals',
      'brandSpotlights',
      'collections',
      'trending',
      'categoryPucks',
    ]) {
      expect(res.body).toHaveProperty(key);
      expect(Array.isArray(res.body[key])).toBe(true);
    }
  });

  it('GET /home/feed surfaces an active HERO banner', async () => {
    const ctx = await createTestUser({ isPlatformAdmin: true });
    const banner = await prisma.banner.create({
      data: {
        placement: 'HERO',
        title: 'Festive Edit',
        subtitle: 'Up to 70% off',
        imageUrl: '/images/home-hero-test.webp',
        bgColor: '#EFE4D6',
        isActive: true,
      },
    });
    try {
      const res = await request(app).get('/home/feed');
      expect(res.status).toBe(200);
      const found = (res.body.heroBanners as Array<{ id: number }>).some(
        (b) => b.id === banner.id,
      );
      expect(found).toBe(true);
    } finally {
      await prisma.banner.delete({ where: { id: banner.id } }).catch(() => undefined);
      await cleanupTestUser(ctx);
    }
  });

  it('GET /home/feed returns active flash deals only', async () => {
    const ctx = await createTestUser();
    const product = await createTestProduct(ctx.shopId, {
      isPublished: true,
      sellingPrice: 199,
      mrp: 599,
    });
    const now = new Date();
    const sale = await prisma.flashSale.create({
      data: {
        shopId: ctx.shopId,
        productId: product.id,
        flashPrice: 99,
        stockLimit: 10,
        startAt: new Date(now.getTime() - 3600_000),
        endAt: new Date(now.getTime() + 3600_000),
        isActive: true,
      },
    });
    try {
      const res = await request(app).get('/home/feed');
      expect(res.status).toBe(200);
      const ids = (res.body.flashDeals as Array<{ id: number }>).map((d) => d.id);
      expect(ids).toContain(sale.id);
    } finally {
      await prisma.flashSale.delete({ where: { id: sale.id } }).catch(() => undefined);
      await cleanupTestUser(ctx);
    }
  });

  it('GET /me/home/personalized requires auth', async () => {
    const res = await request(app).get('/me/home/personalized');
    expect(res.status).toBe(401);
  });

  it('GET /me/home/personalized returns recently-viewed + recommended for the caller', async () => {
    const ctx = await createTestUser();
    const product = await createTestProduct(ctx.shopId, { isPublished: true });
    await prisma.recentlyViewed.create({
      data: {
        userId: ctx.userId,
        productId: product.id,
        lastViewedAt: new Date(),
      },
    });
    try {
      const res = await request(app)
        .get('/me/home/personalized')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.recentlyViewed)).toBe(true);
      expect(Array.isArray(res.body.recommended)).toBe(true);
      const rvIds = (
        res.body.recentlyViewed as Array<{ product: { id: number } }>
      ).map((r) => r.product.id);
      expect(rvIds).toContain(product.id);
    } finally {
      await prisma.recentlyViewed
        .deleteMany({ where: { userId: ctx.userId } })
        .catch(() => undefined);
      await cleanupTestUser(ctx);
    }
  });

  it('GET /me/home/personalized hides unpublished recently-viewed rows', async () => {
    const ctx = await createTestUser();
    const product = await createTestProduct(ctx.shopId, { isPublished: false });
    await prisma.recentlyViewed.create({
      data: { userId: ctx.userId, productId: product.id, lastViewedAt: new Date() },
    });
    try {
      const res = await request(app)
        .get('/me/home/personalized')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(200);
      const rvIds = (
        res.body.recentlyViewed as Array<{ product: { id: number } }>
      ).map((r) => r.product.id);
      expect(rvIds).not.toContain(product.id);
    } finally {
      await prisma.recentlyViewed
        .deleteMany({ where: { userId: ctx.userId } })
        .catch(() => undefined);
      await cleanupTestUser(ctx);
    }
  });
});

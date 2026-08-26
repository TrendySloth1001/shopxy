import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

describe('shop endpoints', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('GET /me/shop returns the caller\'s shop', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.id).toBe(ctx.shopId);
      expect(res.body.slug).toBe(ctx.shopSlug);
      expect(res.body.isPublished).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('PUT /me/shop updates tagline + bannerUrl', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .put('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({
          tagline: 'Best ethnic wear in town',
          bannerUrl: 'https://example.com/banner-md.webp',
        });

      expect(res.status).toBe(200);
      expect(res.body.tagline).toBe('Best ethnic wear in town');
      expect(res.body.bannerUrl).toBe('https://example.com/banner-md.webp');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('PUT /me/shop accepts a server-relative image path from /upload', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .put('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({
          logoUrl: '/images/abc-md.webp',
          bannerUrl: '/images/xyz-md.webp',
        });

      expect(res.status).toBe(200);
      expect(res.body.logoUrl).toBe('/images/abc-md.webp');
      expect(res.body.bannerUrl).toBe('/images/xyz-md.webp');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('PUT /me/shop rejects a clearly malformed image ref', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .put('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ logoUrl: 'not a url' });
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('PUT /me/shop with name change re-slugs and stays unique', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .put('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ name: 'Renamed Shop' });

      expect(res.status).toBe(200);
      expect(res.body.slug).toMatch(/^renamed-shop(-\d+)?$/);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('POST /me/shop/publish toggles isPublished', async () => {
    const ctx = await createTestUser();
    try {
      const on = await request(app)
        .post('/me/shop/publish')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ isPublished: true });
      expect(on.status).toBe(200);
      expect(on.body.isPublished).toBe(true);

      const off = await request(app)
        .post('/me/shop/publish')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ isPublished: false });
      expect(off.body.isPublished).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('GET /shops/:slug is public for published shops', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.shop.update({
        where: { id: ctx.shopId },
        data: { isPublished: true, tagline: 'hi' },
      });

      const res = await request(app).get(`/shops/${ctx.shopSlug}`);
      expect(res.status).toBe(200);
      expect(res.body.slug).toBe(ctx.shopSlug);
      expect(res.body.tagline).toBe('hi');
      expect(res.body).not.toHaveProperty('isPublished');
      expect(res.body).not.toHaveProperty('ownerUserId');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('GET /shops/:slug 404s when the shop is unpublished (no info leak)', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app).get(`/shops/${ctx.shopSlug}`);
      expect(res.status).toBe(404);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('GET /shops/:slug rejects invalid slug shapes', async () => {
    const res = await request(app).get('/shops/INVALID%20slug!');
    expect(res.status).toBe(400);
  });

  it('GET /me/shop requires auth', async () => {
    const res = await request(app).get('/me/shop');
    expect(res.status).toBe(401);
  });

  it('GET /me/shop forbids CUSTOMER role', async () => {
    const ctx = await createTestUser({ role: 'CUSTOMER' });
    try {
      const res = await request(app)
        .get('/me/shop')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});

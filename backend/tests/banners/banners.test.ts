import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { getRedis, pingRedis, closeRedis } from '../../src/infra/redis.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

async function clearAllTestBanners() {
  await prisma.banner.deleteMany({});
}

describe('banners — admin CRUD + cache invalidation', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });

  afterAll(async () => {
    await clearAllTestBanners();
    await closeRedis();
    await prisma.$disconnect();
  });

  it('forbids non-platform-admin from writing banners', async () => {
    const merchant = await createTestUser({ isPlatformAdmin: false });
    try {
      const res = await request(app)
        .post('/admin/banners')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ placement: 'HERO', imageUrl: '/images/test-md.webp' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('platform admin creates, reads, updates, deletes a banner', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const create = await request(app)
        .post('/admin/banners')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({
          placement: 'HERO',
          imageUrl: '/images/banner-md.webp',
          linkUrl: '/search?q=fashion',
          sortOrder: 1,
        });
      expect(create.status).toBe(201);
      const id = create.body.id;
      expect(typeof id).toBe('number');

      const get = await request(app)
        .get(`/admin/banners/${id}`)
        .set('Authorization', `Bearer ${admin.accessToken}`);
      expect(get.status).toBe(200);
      expect(get.body.imageUrl).toBe('/images/banner-md.webp');
      expect(get.body.linkUrl).toBe('/search?q=fashion');

      const patch = await request(app)
        .patch(`/admin/banners/${id}`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ linkUrl: '/shop/festive' });
      expect(patch.body.linkUrl).toBe('/shop/festive');

      const del = await request(app)
        .delete(`/admin/banners/${id}`)
        .set('Authorization', `Bearer ${admin.accessToken}`);
      expect(del.status).toBe(204);
    } finally {
      await cleanupTestUser(admin);
    }
  });

  it('rejects an invalid linkUrl', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const res = await request(app)
        .post('/admin/banners')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({
          placement: 'HERO',
          imageUrl: '/images/x-md.webp',
          linkUrl: 'javascript:alert(1)',
        });
      expect([400, 422]).toContain(res.status);
    } finally {
      await cleanupTestUser(admin);
    }
  });

  it('rejects a missing imageUrl', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const res = await request(app)
        .post('/admin/banners')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ placement: 'HERO' });
      expect([400, 422]).toContain(res.status);
    } finally {
      await cleanupTestUser(admin);
    }
  });
});

describe('banners — public read + scheduling window', () => {
  afterAll(async () => {
    await clearAllTestBanners();
    await prisma.$disconnect();
  });

  it('GET /banners?placement=HERO returns only active + in-window rows', async () => {
    await clearAllTestBanners();

    const now = new Date();
    const yesterday = new Date(now.getTime() - 86_400_000);
    const tomorrow = new Date(now.getTime() + 86_400_000);

    // 3 rows: active+in-window, active+future, inactive.
    const live = await prisma.banner.create({
      data: {
        placement: 'HERO',
        imageUrl: '/images/a-md.webp',
        startAt: yesterday,
        endAt: tomorrow,
      },
    });
    await prisma.banner.create({
      data: {
        placement: 'HERO',
        imageUrl: '/images/b-md.webp',
        startAt: tomorrow,
        endAt: null,
      },
    });
    await prisma.banner.create({
      data: {
        placement: 'HERO',
        imageUrl: '/images/c-md.webp',
        isActive: false,
      },
    });

    const res = await request(app).get('/banners?placement=HERO');
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.data[0].id).toBe(live.id);
  });

  it('rejects missing/invalid placement', async () => {
    const res = await request(app).get('/banners?placement=BOGUS');
    expect(res.status).toBe(400);

    const res2 = await request(app).get('/banners');
    expect(res2.status).toBe(400);
  });

  it('write invalidates Redis cache so the next read sees the change', async () => {
    if (!(await pingRedis().catch(() => false))) {
      // Redis not running locally — skip; cache helpers degrade gracefully
      // and the un-cached path is covered by the previous test.
      return;
    }
    await clearAllTestBanners();
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      // 1. Read empty → caches `[]`.
      const first = await request(app).get('/banners?placement=PROMO');
      expect(first.body.data.length).toBe(0);
      const cachedRaw = await getRedis().get('banners:active:PROMO');
      expect(cachedRaw).toBe('[]');

      // 2. Admin writes a new active banner.
      const created = await request(app)
        .post('/admin/banners')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ placement: 'PROMO', imageUrl: '/images/promo-md.webp' });

      // 3. Cache should have been deleted by the write.
      const cachedAfter = await getRedis().get('banners:active:PROMO');
      expect(cachedAfter).toBeNull();

      // 4. Next read returns the new row + repopulates the cache.
      const second = await request(app).get('/banners?placement=PROMO');
      expect(second.body.data.length).toBe(1);
      expect(second.body.data[0].id).toBe(created.body.id);
    } finally {
      await cleanupTestUser(admin);
    }
  });
});

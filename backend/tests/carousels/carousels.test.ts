import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { pingRedis, closeRedis } from '../../src/infra/redis.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

async function createCarousel(
  token: string,
  body: Partial<{ name: string; placement: string }> = {},
) {
  return request(app)
    .post('/me/carousels')
    .set('Authorization', `Bearer ${token}`)
    .send({
      name: body.name ?? 'Test campaign',
      placement: body.placement ?? 'HERO',
    });
}

async function createSlide(
  token: string,
  carouselId: number,
  body: Record<string, unknown> = {},
) {
  return request(app)
    .post(`/me/carousels/${carouselId}/slides`)
    .set('Authorization', `Bearer ${token}`)
    .send({
      title: 'Slide title',
      imageUrl: '/images/test-md.webp',
      bgColor: '#EFE4D6',
      ...body,
    });
}

describe('carousels — merchant CRUD + tenant scoping', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });

  afterAll(async () => {
    await closeRedis();
    await prisma.$disconnect();
  });

  it('requires auth', async () => {
    const res = await request(app).get('/me/carousels');
    expect(res.status).toBe(401);
  });

  it('owner creates and reads their carousel', async () => {
    const merchant = await createTestUser();
    try {
      const created = await createCarousel(merchant.accessToken, {
        name: 'Spring sale',
      });
      expect(created.status).toBe(201);
      expect(created.body.name).toBe('Spring sale');
      expect(created.body.placement).toBe('HERO');
      expect(created.body.shopId).toBe(merchant.shopId);

      const list = await request(app)
        .get('/me/carousels')
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(list.status).toBe(200);
      expect(list.body.data).toHaveLength(1);
      expect(list.body.data[0]._count.slides).toBe(0);
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('cross-shop probe returns 404 instead of leaking another shop carousel', async () => {
    const ownerA = await createTestUser();
    const ownerB = await createTestUser();
    try {
      const created = await createCarousel(ownerA.accessToken, {
        name: 'A only',
      });
      const cid = created.body.id;
      expect(cid).toBeGreaterThan(0);

      // Owner B id-probes A's carousel — must 404, not 200/403.
      const probeGet = await request(app)
        .get(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${ownerB.accessToken}`);
      expect(probeGet.status).toBe(404);

      const probePatch = await request(app)
        .patch(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${ownerB.accessToken}`)
        .send({ name: 'pwned' });
      expect(probePatch.status).toBe(404);

      const probeDelete = await request(app)
        .delete(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${ownerB.accessToken}`);
      expect(probeDelete.status).toBe(404);

      // Slide probe with B's token against A's carousel — must 404.
      const probeSlides = await request(app)
        .get(`/me/carousels/${cid}/slides`)
        .set('Authorization', `Bearer ${ownerB.accessToken}`);
      expect(probeSlides.status).toBe(404);

      // Confirm owner A's carousel is untouched after the probes.
      const stillThere = await request(app)
        .get(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${ownerA.accessToken}`);
      expect(stillThere.status).toBe(200);
      expect(stillThere.body.name).toBe('A only');
    } finally {
      await prisma.carousel.deleteMany({
        where: { shopId: { in: [ownerA.shopId, ownerB.shopId] } },
      });
      await cleanupTestUser(ownerA);
      await cleanupTestUser(ownerB);
    }
  });

  it('creates a templated slide and a freeform slide under the same carousel', async () => {
    const merchant = await createTestUser();
    try {
      const c = await createCarousel(merchant.accessToken);
      const cid = c.body.id;

      const templated = await createSlide(merchant.accessToken, cid, {
        title: 'Templated',
        template: 'DEAL',
        imageFit: 'CONTAIN',
      });
      expect(templated.status).toBe(201);
      expect(templated.body.mode).toBe('TEMPLATED');
      expect(templated.body.template).toBe('DEAL');
      expect(templated.body.imageFit).toBe('CONTAIN');
      // Placement should be inherited from the carousel.
      expect(templated.body.placement).toBe('HERO');
      // Slide auto-stamped with the merchant's sponsorShopId.
      expect(templated.body.sponsorShopId).toBe(merchant.shopId);

      const freeform = await createSlide(merchant.accessToken, cid, {
        title: 'Freeform',
        mode: 'FREEFORM',
        textBlocks: [
          {
            id: 'b1',
            text: 'Hello',
            xPct: 10,
            yPct: 20,
            widthPct: 40,
            fontSize: 24,
            color: '#000000',
            weight: 700,
            align: 'left',
          },
        ],
        imageTransform: {
          focalXPct: 50,
          focalYPct: 50,
          scale: 1.2,
          rotateDeg: 0,
          flipH: false,
          flipV: false,
          brightness: 1,
          contrast: 1,
          saturation: 1,
        },
      });
      expect(freeform.status).toBe(201);
      expect(freeform.body.mode).toBe('FREEFORM');
      expect(Array.isArray(freeform.body.textBlocks)).toBe(true);
      expect(freeform.body.textBlocks[0].text).toBe('Hello');
      expect(freeform.body.imageTransform.scale).toBe(1.2);

      const list = await request(app)
        .get(`/me/carousels/${cid}/slides`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(list.status).toBe(200);
      expect(list.body.data).toHaveLength(2);
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('rejects oversized payloads with 400', async () => {
    const merchant = await createTestUser();
    try {
      const c = await createCarousel(merchant.accessToken);
      const cid = c.body.id;

      const tooManyBlocks = await createSlide(merchant.accessToken, cid, {
        mode: 'FREEFORM',
        textBlocks: Array.from({ length: 9 }, (_, i) => ({
          id: `b${i}`,
          text: 'x',
          xPct: 0,
          yPct: 0,
          widthPct: 10,
          fontSize: 12,
          color: '#000000',
          weight: 400,
          align: 'left',
        })),
      });
      expect(tooManyBlocks.status).toBe(400);

      const badScale = await createSlide(merchant.accessToken, cid, {
        mode: 'FREEFORM',
        imageTransform: {
          focalXPct: 50,
          focalYPct: 50,
          scale: 99, // > 4
          rotateDeg: 0,
          flipH: false,
          flipV: false,
          brightness: 1,
          contrast: 1,
          saturation: 1,
        },
      });
      expect(badScale.status).toBe(400);

      const badColor = await createSlide(merchant.accessToken, cid, {
        mode: 'FREEFORM',
        textBlocks: [
          {
            id: 'b1',
            text: 'Hi',
            xPct: 0,
            yPct: 0,
            widthPct: 10,
            fontSize: 12,
            color: 'red', // not hex
            weight: 400,
            align: 'left',
          },
        ],
      });
      expect(badColor.status).toBe(400);
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('deleting a carousel cascades its slides', async () => {
    const merchant = await createTestUser();
    try {
      const c = await createCarousel(merchant.accessToken);
      const cid = c.body.id;
      await createSlide(merchant.accessToken, cid, { title: 'A' });
      await createSlide(merchant.accessToken, cid, { title: 'B' });

      const before = await prisma.banner.count({ where: { carouselId: cid } });
      expect(before).toBe(2);

      const del = await request(app)
        .delete(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(del.status).toBe(204);

      // Cascade is on the FK (ON DELETE SET NULL today — Phase 7 will
      // tighten to CASCADE once every slide has a carouselId). Either
      // way the slide should no longer point at this carousel.
      const after = await prisma.banner.count({ where: { carouselId: cid } });
      expect(after).toBe(0);
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await prisma.banner.deleteMany({
        where: { sponsorShopId: merchant.shopId },
      });
      await cleanupTestUser(merchant);
    }
  });

  it('public /banners reader hides slides of an inactive carousel', async () => {
    const merchant = await createTestUser();
    try {
      const c = await createCarousel(merchant.accessToken);
      const cid = c.body.id;
      await createSlide(merchant.accessToken, cid, { title: 'Visible' });

      // Confirm it shows up before deactivation.
      const before = await request(app).get('/banners?placement=HERO');
      expect(before.status).toBe(200);
      const beforeIds = (before.body.data as Array<{ carouselId: number }>)
        .filter((b) => b.carouselId === cid)
        .map((b) => b.carouselId);
      expect(beforeIds).toContain(cid);

      // Flip the carousel off; the slide row itself stays active.
      await request(app)
        .patch(`/me/carousels/${cid}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ isActive: false });

      const after = await request(app).get('/banners?placement=HERO');
      expect(after.status).toBe(200);
      const afterIds = (after.body.data as Array<{ carouselId: number }>)
        .filter((b) => b.carouselId === cid)
        .map((b) => b.carouselId);
      expect(afterIds).toHaveLength(0);
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await prisma.banner.deleteMany({
        where: { sponsorShopId: merchant.shopId },
      });
      await cleanupTestUser(merchant);
    }
  });
});

describe('carousels — admin endpoints', () => {
  afterAll(async () => {
    await closeRedis();
    await prisma.$disconnect();
  });

  it('forbids non-platform-admin from listing all carousels', async () => {
    const merchant = await createTestUser({ isPlatformAdmin: false });
    try {
      const res = await request(app)
        .get('/admin/carousels')
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('platform admin lists carousels across shops', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    const merchant = await createTestUser();
    try {
      await createCarousel(merchant.accessToken, { name: 'A' });
      await createCarousel(merchant.accessToken, { name: 'B' });

      const res = await request(app)
        .get('/admin/carousels')
        .set('Authorization', `Bearer ${admin.accessToken}`);
      expect(res.status).toBe(200);
      const names = (res.body.data as Array<{ name: string }>).map(
        (c) => c.name,
      );
      expect(names).toEqual(expect.arrayContaining(['A', 'B']));
    } finally {
      await prisma.carousel.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
      await cleanupTestUser(admin);
    }
  });
});

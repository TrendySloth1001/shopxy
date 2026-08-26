import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import crypto from 'crypto';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { eventsService } from '../../src/modules/events/events.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

const ISO = (d: Date) => d.toISOString();
const uuid = () => crypto.randomBytes(8).toString('hex');

describe('events — POST /v1/events ingest', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('rejects unauthenticated requests', async () => {
    const res = await request(app).post('/v1/events').send({ events: [] });
    expect(res.status).toBe(401);
  });

  it('rejects empty batch (zod 400)', async () => {
    const user = await createTestUser();
    try {
      const res = await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ events: [] });
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(user);
    }
  });

  it('rejects batches exceeding the 100-event cap', async () => {
    const user = await createTestUser();
    try {
      const product = await createTestProduct(user.shopId);
      const events = Array.from({ length: 101 }, () => ({
        clientUuid: uuid(),
        eventType: 'IMPRESSION',
        productId: product.id,
        occurredAt: ISO(new Date()),
      }));
      const res = await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ events });
      expect(res.status).toBe(400);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('ingests a batch + retried submission deduplicates by clientUuid', async () => {
    const user = await createTestUser();
    try {
      const product = await createTestProduct(user.shopId);
      const events = [
        {
          clientUuid: uuid(),
          eventType: 'IMPRESSION',
          productId: product.id,
          occurredAt: ISO(new Date()),
        },
        {
          clientUuid: uuid(),
          eventType: 'TAP',
          productId: product.id,
          occurredAt: ISO(new Date()),
        },
      ];
      const first = await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ events });
      expect(first.status).toBe(202);
      expect(first.body.inserted).toBe(2);
      expect(first.body.deduped).toBe(0);

      const replay = await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ events });
      expect(replay.status).toBe(202);
      expect(replay.body.inserted).toBe(0);
      expect(replay.body.deduped).toBe(2);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('drops unknown productIds silently and reports them back', async () => {
    const user = await createTestUser();
    try {
      const product = await createTestProduct(user.shopId);
      const ghost = 9_999_999;
      const res = await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          events: [
            {
              clientUuid: uuid(),
              eventType: 'IMPRESSION',
              productId: product.id,
              occurredAt: ISO(new Date()),
            },
            {
              clientUuid: uuid(),
              eventType: 'IMPRESSION',
              productId: ghost,
              occurredAt: ISO(new Date()),
            },
          ],
        });
      expect(res.status).toBe(202);
      expect(res.body.inserted).toBe(1);
      expect(res.body.unknownProductIds).toContain(ghost);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('VIEW events upsert RecentlyViewed for the caller', async () => {
    const user = await createTestUser();
    try {
      const p1 = await createTestProduct(user.shopId);
      const p2 = await createTestProduct(user.shopId);
      const t0 = new Date(Date.now() - 60_000);
      const t1 = new Date();
      await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          events: [
            {
              clientUuid: uuid(),
              eventType: 'VIEW',
              productId: p1.id,
              occurredAt: ISO(t0),
            },
            {
              clientUuid: uuid(),
              eventType: 'VIEW',
              productId: p2.id,
              occurredAt: ISO(t1),
            },
          ],
        });

      const list = await request(app)
        .get('/me/recently-viewed')
        .set('Authorization', `Bearer ${user.accessToken}`);
      expect(list.status).toBe(200);
      expect(
        list.body.data.map((r: { product: { id: number } }) => r.product.id),
      ).toEqual([p2.id, p1.id]);
    } finally {
      await prisma.recentlyViewed.deleteMany({ where: { userId: user.userId } });
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('a second VIEW of the same product bumps lastViewedAt (no duplicate row)', async () => {
    const user = await createTestUser();
    try {
      const product = await createTestProduct(user.shopId);
      const t0 = new Date(Date.now() - 60_000);
      const t1 = new Date();
      await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          events: [
            {
              clientUuid: uuid(),
              eventType: 'VIEW',
              productId: product.id,
              occurredAt: ISO(t0),
            },
          ],
        });
      await request(app)
        .post('/v1/events')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          events: [
            {
              clientUuid: uuid(),
              eventType: 'VIEW',
              productId: product.id,
              occurredAt: ISO(t1),
            },
          ],
        });

      const rows = await prisma.recentlyViewed.findMany({
        where: { userId: user.userId, productId: product.id },
      });
      expect(rows).toHaveLength(1);
      expect(rows[0].lastViewedAt.getTime()).toBeCloseTo(t1.getTime(), -2);
    } finally {
      await prisma.recentlyViewed.deleteMany({ where: { userId: user.userId } });
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('one users events do not bleed into anothers /me/recently-viewed', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const product = await createTestProduct(a.shopId);
      await prisma.recentlyViewed.create({
        data: { userId: a.userId, productId: product.id },
      });

      const list = await request(app)
        .get('/me/recently-viewed')
        .set('Authorization', `Bearer ${b.accessToken}`);
      expect(list.status).toBe(200);
      expect(list.body.data).toHaveLength(0);
    } finally {
      await prisma.recentlyViewed.deleteMany({ where: { userId: a.userId } });
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });
});

describe('events — cron helpers', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('trimRecentlyViewed caps each user at 20 rows', async () => {
    const user = await createTestUser();
    try {
      const products = [] as Array<{ id: number }>;
      for (let i = 0; i < 25; i++) {
        products.push(await createTestProduct(user.shopId));
      }
      await prisma.recentlyViewed.createMany({
        data: products.map((p, i) => ({
          userId: user.userId,
          productId: p.id,
          lastViewedAt: new Date(Date.now() - i * 60_000),
        })),
      });
      const result = await eventsService.trimRecentlyViewed();
      expect(result.deleted).toBeGreaterThanOrEqual(5);
      const remaining = await prisma.recentlyViewed.count({
        where: { userId: user.userId },
      });
      expect(remaining).toBe(20);
    } finally {
      await prisma.recentlyViewed.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('pruneOldEvents drops rows older than 90 days', async () => {
    const user = await createTestUser();
    try {
      const product = await createTestProduct(user.shopId);
      const oldRow = await prisma.productEvent.create({
        data: {
          clientUuid: uuid(),
          eventType: 'IMPRESSION',
          productId: product.id,
          userId: user.userId,
          occurredAt: new Date(Date.now() - 100 * 86_400_000),
        },
      });
      const recent = await prisma.productEvent.create({
        data: {
          clientUuid: uuid(),
          eventType: 'IMPRESSION',
          productId: product.id,
          userId: user.userId,
          occurredAt: new Date(),
        },
      });
      const result = await eventsService.pruneOldEvents();
      expect(result.deleted).toBeGreaterThanOrEqual(1);

      const stillThere = await prisma.productEvent.findUnique({
        where: { id: oldRow.id },
      });
      expect(stillThere).toBeNull();
      const recentAfter = await prisma.productEvent.findUnique({
        where: { id: recent.id },
      });
      expect(recentAfter).not.toBeNull();
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });
});

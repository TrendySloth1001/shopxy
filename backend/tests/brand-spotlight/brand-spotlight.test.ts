import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

const minutes = (n: number) => new Date(Date.now() + n * 60_000);
const ISO = (d: Date) => d.toISOString();

function payload(overrides: Partial<{ startAt: string; endAt: string }> = {}) {
  return {
    dealLabel: 'Brand of the Day',
    subtitle: 'Up to 40% off',
    heroImageUrl: 'https://example.com/hero-md.webp',
    bgColor: '#FFE4E1',
    accentColor: '#B23A2E',
    ctaTarget: 'collection:wedding-edit',
    startAt: overrides.startAt ?? ISO(minutes(-1)),
    endAt: overrides.endAt ?? ISO(minutes(60)),
  };
}

describe('brand-spotlight — merchant submit & cancel', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('merchant submits, the row lands as PENDING tied to caller-shop', async () => {
    const merchant = await createTestUser();
    try {
      const res = await request(app)
        .post('/me/brand-spotlight/request')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send(payload());
      expect(res.status).toBe(201);
      expect(res.body.status).toBe('PENDING');
      expect(res.body.shopId).toBe(merchant.shopId);
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('lists only the caller-shops own spotlights', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      await prisma.brandSpotlight.create({
        data: { shopId: a.shopId, ...payload(), startAt: minutes(-1), endAt: minutes(60) },
      });
      const list = await request(app)
        .get('/me/brand-spotlight')
        .set('Authorization', `Bearer ${b.accessToken}`);
      expect(list.status).toBe(200);
      expect(list.body.data).toHaveLength(0);
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: { in: [a.shopId, b.shopId] } } });
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });

  it('rejects scheduling window where endAt <= startAt', async () => {
    const merchant = await createTestUser();
    try {
      const res = await request(app)
        .post('/me/brand-spotlight/request')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send(payload({ startAt: ISO(minutes(60)), endAt: ISO(minutes(-1)) }));
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('cancel works on PENDING; conflicts on APPROVED', async () => {
    const merchant = await createTestUser();
    try {
      const created = await prisma.brandSpotlight.create({
        data: { shopId: merchant.shopId, ...payload(), startAt: minutes(-1), endAt: minutes(60) },
      });
      const ok = await request(app)
        .delete(`/me/brand-spotlight/${created.id}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(ok.status).toBe(204);

      const approved = await prisma.brandSpotlight.create({
        data: {
          shopId: merchant.shopId,
          ...payload(),
          status: 'APPROVED',
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      const conflict = await request(app)
        .delete(`/me/brand-spotlight/${approved.id}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(conflict.status).toBe(409);
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });
});

describe('brand-spotlight — admin queue + approve/reject', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('non-platform-admin cannot touch /admin/brand-spotlight', async () => {
    const merchant = await createTestUser({ isPlatformAdmin: false });
    try {
      const res = await request(app)
        .get('/admin/brand-spotlight')
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('admin approves a PENDING spotlight; it becomes publicly visible', async () => {
    const merchant = await createTestUser();
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const created = await prisma.brandSpotlight.create({
        data: { shopId: merchant.shopId, ...payload(), startAt: minutes(-1), endAt: minutes(60) },
      });
      const approve = await request(app)
        .patch(`/admin/brand-spotlight/${created.id}/approve`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({});
      expect(approve.status).toBe(200);
      expect(approve.body.status).toBe('APPROVED');
      expect(approve.body.reviewedByUserId).toBe(admin.userId);

      const pub = await request(app).get('/brand-spotlights/active');
      expect(pub.status).toBe(200);
      expect(pub.body.data.find((r: { id: number }) => r.id === created.id)).toBeTruthy();
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
      await cleanupTestUser(admin);
    }
  });

  it('admin rejects with a reason; stays hidden from public', async () => {
    const merchant = await createTestUser();
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const created = await prisma.brandSpotlight.create({
        data: { shopId: merchant.shopId, ...payload(), startAt: minutes(-1), endAt: minutes(60) },
      });
      const reject = await request(app)
        .patch(`/admin/brand-spotlight/${created.id}/reject`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ reason: 'Image quality too low' });
      expect(reject.status).toBe(200);
      expect(reject.body.status).toBe('REJECTED');
      expect(reject.body.rejectionReason).toBe('Image quality too low');

      const pub = await request(app).get('/brand-spotlights/active');
      expect(pub.body.data.find((r: { id: number }) => r.id === created.id)).toBeFalsy();
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
      await cleanupTestUser(admin);
    }
  });

  it('public listActive excludes APPROVED rows outside their window', async () => {
    const merchant = await createTestUser();
    try {
      const future = await prisma.brandSpotlight.create({
        data: {
          shopId: merchant.shopId, ...payload(),
          status: 'APPROVED', startAt: minutes(60), endAt: minutes(120),
        },
      });
      const past = await prisma.brandSpotlight.create({
        data: {
          shopId: merchant.shopId, ...payload(),
          status: 'APPROVED', startAt: minutes(-120), endAt: minutes(-60),
        },
      });
      const live = await prisma.brandSpotlight.create({
        data: {
          shopId: merchant.shopId, ...payload(),
          status: 'APPROVED', startAt: minutes(-1), endAt: minutes(60),
        },
      });
      const res = await request(app).get('/brand-spotlights/active');
      const ids = res.body.data.map((r: { id: number }) => r.id);
      expect(ids).toContain(live.id);
      expect(ids).not.toContain(future.id);
      expect(ids).not.toContain(past.id);
    } finally {
      await prisma.brandSpotlight.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });
});

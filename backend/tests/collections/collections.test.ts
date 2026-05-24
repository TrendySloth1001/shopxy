import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

describe('collections — admin CRUD + slug suffixing', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('forbids non-platform-admin from writing collections', async () => {
    const merchant = await createTestUser({ isPlatformAdmin: false });
    try {
      const res = await request(app)
        .post('/admin/collections')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ title: 'Wedding Edit' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('creates two collections with same title — slug auto-suffixes', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const a = await request(app)
        .post('/admin/collections')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ title: 'Wedding Edit', isPublished: true });
      const b = await request(app)
        .post('/admin/collections')
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ title: 'Wedding Edit' });
      expect(a.status).toBe(201);
      expect(b.status).toBe(201);
      expect(a.body.slug).toBe('wedding-edit');
      expect(b.body.slug).toBe('wedding-edit-2');
      // cleanup
      await prisma.collection.deleteMany({
        where: { id: { in: [a.body.id, b.body.id] } },
      });
    } finally {
      await cleanupTestUser(admin);
    }
  });

  it('update with explicit slug re-suffixes against other rows', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const a = await prisma.collection.create({
        data: { slug: 'taken', title: 'A' },
      });
      const b = await prisma.collection.create({
        data: { slug: 'other', title: 'B' },
      });
      const res = await request(app)
        .patch(`/admin/collections/${b.id}`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ slug: 'taken' });
      expect(res.status).toBe(200);
      expect(res.body.slug).toBe('taken-2');
      await prisma.collection.deleteMany({ where: { id: { in: [a.id, b.id] } } });
    } finally {
      await cleanupTestUser(admin);
    }
  });
});

describe('collections — items + public read', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('replaces items in order; out-of-order positions persist verbatim', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    const merchant = await createTestUser();
    try {
      const collection = await prisma.collection.create({
        data: { slug: `t-${Date.now()}-items`, title: 'T', isPublished: true },
      });
      const p1 = await createTestProduct(merchant.shopId);
      const p2 = await createTestProduct(merchant.shopId);
      const p3 = await createTestProduct(merchant.shopId);

      const put = await request(app)
        .put(`/admin/collections/${collection.id}/items`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({
          items: [
            { productId: p3.id, position: 0 },
            { productId: p1.id, position: 1 },
            { productId: p2.id, position: 2 },
          ],
        });
      expect(put.status).toBe(200);
      expect(put.body.data.map((r: { product: { id: number } }) => r.product.id))
        .toEqual([p3.id, p1.id, p2.id]);

      // Replace again — old items go, new order takes hold (no duplicates).
      const second = await request(app)
        .put(`/admin/collections/${collection.id}/items`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({
          items: [
            { productId: p2.id, position: 0 },
            { productId: p3.id, position: 1 },
          ],
        });
      expect(second.status).toBe(200);
      expect(second.body.data).toHaveLength(2);

      await prisma.collection.delete({ where: { id: collection.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(admin);
    }
  });

  it('replaceItems with bogus productId returns 400', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    try {
      const collection = await prisma.collection.create({
        data: { slug: `t-${Date.now()}-bogus`, title: 'T' },
      });
      const res = await request(app)
        .put(`/admin/collections/${collection.id}/items`)
        .set('Authorization', `Bearer ${admin.accessToken}`)
        .send({ items: [{ productId: 9_999_999, position: 0 }] });
      expect(res.status).toBe(400);
      await prisma.collection.delete({ where: { id: collection.id } });
    } finally {
      await cleanupTestUser(admin);
    }
  });

  it('public list returns only published collections', async () => {
    const merchant = await createTestUser();
    try {
      const draftSlug = `draft-${Date.now()}`;
      const pubSlug = `pub-${Date.now()}`;
      const draft = await prisma.collection.create({
        data: { slug: draftSlug, title: 'Draft', isPublished: false },
      });
      const pub = await prisma.collection.create({
        data: { slug: pubSlug, title: 'Public', isPublished: true },
      });
      const res = await request(app).get('/collections');
      expect(res.status).toBe(200);
      const slugs = res.body.data.map((r: { slug: string }) => r.slug);
      expect(slugs).toContain(pubSlug);
      expect(slugs).not.toContain(draftSlug);
      await prisma.collection.deleteMany({ where: { id: { in: [draft.id, pub.id] } } });
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('public detail returns 404 for unpublished slug', async () => {
    const draftSlug = `priv-${Date.now()}`;
    const c = await prisma.collection.create({
      data: { slug: draftSlug, title: 'Hidden', isPublished: false },
    });
    const res = await request(app).get(`/collections/${draftSlug}`);
    expect(res.status).toBe(404);
    await prisma.collection.delete({ where: { id: c.id } });
  });

  it('public detail paginates items via cursor', async () => {
    const admin = await createTestUser({ isPlatformAdmin: true });
    const merchant = await createTestUser();
    try {
      const collection = await prisma.collection.create({
        data: { slug: `p-${Date.now()}-paged`, title: 'Paged', isPublished: true },
      });
      const products = [] as Array<{ id: number }>;
      for (let i = 0; i < 3; i++) {
        products.push(await createTestProduct(merchant.shopId));
      }
      await prisma.collectionItem.createMany({
        data: products.map((p, i) => ({
          collectionId: collection.id,
          productId: p.id,
          position: i,
        })),
      });
      const page1 = await request(app).get(`/collections/${collection.slug}?limit=2`);
      expect(page1.status).toBe(200);
      expect(page1.body.items).toHaveLength(2);
      expect(page1.body.nextCursor).not.toBeNull();

      const page2 = await request(app).get(
        `/collections/${collection.slug}?limit=2&cursor=${page1.body.nextCursor}`,
      );
      expect(page2.body.items).toHaveLength(1);
      expect(page2.body.nextCursor).toBeNull();

      await prisma.collection.delete({ where: { id: collection.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(admin);
    }
  });
});

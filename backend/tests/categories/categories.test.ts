import { describe, it, expect, afterAll, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

async function preExistingIds(): Promise<Set<number>> {
  const all = await prisma.category.findMany({ select: { id: true } });
  return new Set(all.map((c) => c.id));
}
async function cleanupNewCategories(before: Set<number>) {
  const after = await prisma.category.findMany({ select: { id: true } });
  const created = after.filter((c) => !before.has(c.id)).map((c) => c.id);
  if (created.length > 0) {
    await prisma.category.deleteMany({ where: { id: { in: created } } });
  }
}

describe('categories — slug auto-generate + uniqueness', () => {
  let baseline: Set<number> = new Set();
  afterEach(async () => {
    await cleanupNewCategories(baseline);
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('POST /categories derives a slug from the name', async () => {
    baseline = await preExistingIds();
    const owner = await createTestUser({ isPlatformAdmin: true });
    try {
      const res = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Wedding Wear & More!' });
      expect(res.status).toBe(201);
      expect(res.body.slug).toMatch(/^wedding-wear-more(-\d+)?$/);
    } finally {
      await cleanupTestUser(owner);
    }
  });

  it('disambiguates duplicate slugs with a numeric suffix', async () => {
    baseline = await preExistingIds();
    const owner = await createTestUser({ isPlatformAdmin: true });
    try {
      const first = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'OutdoorsTest' });
      const second = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'outdoorstest' });
      expect(first.status).toBe(201);
      expect(second.status).toBe(201);
      expect(first.body.slug).toBe('outdoorstest');
      expect(second.body.slug).toBe('outdoorstest-2');
    } finally {
      await cleanupTestUser(owner);
    }
  });
});

describe('categories — taxonomy tree + cycle prevention', () => {
  let baseline: Set<number> = new Set();
  afterEach(async () => {
    await cleanupNewCategories(baseline);
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('GET /categories/tree returns nested parent→children shape', async () => {
    baseline = await preExistingIds();
    const owner = await createTestUser({ isPlatformAdmin: true });
    try {
      const beauty = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Beauty TreeTest' });
      const skincare = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Skincare TreeTest', parentId: beauty.body.id });
      const serums = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Serums TreeTest', parentId: skincare.body.id });

      const tree = await request(app)
        .get('/categories/tree')
        .set('Authorization', `Bearer ${owner.accessToken}`);
      expect(tree.status).toBe(200);

      const beautyNode = (tree.body.data as Array<{ id: number; children: unknown[] }>)
        .find((n) => n.id === beauty.body.id);
      expect(beautyNode).toBeDefined();
      type Node = { id: number; children: Node[] };
      const skincareNode = (beautyNode as unknown as Node).children
        .find((n) => n.id === skincare.body.id);
      expect(skincareNode).toBeDefined();
      expect(skincareNode!.children.length).toBe(1);
      expect(skincareNode!.children[0].id).toBe(serums.body.id);
    } finally {
      await cleanupTestUser(owner);
    }
  });

  it('rejects re-parenting that would form a cycle', async () => {
    baseline = await preExistingIds();
    const owner = await createTestUser({ isPlatformAdmin: true });
    try {
      const a = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Cycle A' });
      const b = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Cycle B', parentId: a.body.id });
      const c = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Cycle C', parentId: b.body.id });

      const bad = await request(app)
        .patch(`/categories/${a.body.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ parentId: c.body.id });
      expect(bad.status).toBe(400);
      expect(bad.body.error).toMatch(/cycle/i);

      const self = await request(app)
        .patch(`/categories/${a.body.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ parentId: a.body.id });
      expect(self.status).toBe(400);
    } finally {
      await cleanupTestUser(owner);
    }
  });

  it('rename re-derives the slug uniquely', async () => {
    baseline = await preExistingIds();
    const owner = await createTestUser({ isPlatformAdmin: true });
    try {
      const created = await request(app)
        .post('/categories')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Original Cat' });
      expect(created.body.slug).toMatch(/^original-cat(-\d+)?$/);

      const renamed = await request(app)
        .patch(`/categories/${created.body.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Renamed Cat' });
      expect(renamed.body.slug).toMatch(/^renamed-cat(-\d+)?$/);
    } finally {
      await cleanupTestUser(owner);
    }
  });
});

import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { pingRedis, closeRedis, getRedis, redisAvailable } from '../../src/infra/redis.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

async function clearHintsCache() {
  if (redisAvailable()) {
    await getRedis().del('search:hints:top10').catch(() => undefined);
  }
}

describe('search — POST /search', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });
  afterAll(async () => {
    await clearHintsCache();
    await closeRedis();
    await prisma.$disconnect();
  });

  it('returns published products that match the query', async () => {
    const merchant = await createTestUser();
    try {
      const exact = await createTestProduct(merchant.shopId, {
        name: `BananaSearch ${Date.now()}`,
        isPublished: true,
      });
      const other = await createTestProduct(merchant.shopId, {
        name: 'Unrelated widget',
        isPublished: true,
      });

      const res = await request(app)
        .post('/search')
        .send({ q: 'bananasearch' });
      expect(res.status).toBe(200);
      const ids = res.body.results.map((r: { id: number }) => r.id);
      expect(ids).toContain(exact.id);
      expect(ids).not.toContain(other.id);
    } finally {
      // Only clean rows this test created — bulk-delete would race
      // with concurrent search tests running in parallel files.
      await prisma.searchEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('hides unpublished products', async () => {
    const merchant = await createTestUser();
    try {
      const draft = await createTestProduct(merchant.shopId, {
        name: `DraftSearch ${Date.now()}`,
        isPublished: false,
      });
      const res = await request(app).post('/search').send({ q: 'draftsearch' });
      expect(res.status).toBe(200);
      const ids = res.body.results.map((r: { id: number }) => r.id);
      expect(ids).not.toContain(draft.id);
    } finally {
      // Only clean rows this test created — bulk-delete would race
      // with concurrent search tests running in parallel files.
      await prisma.searchEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('respects shopId filter', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const tag = `FilterTok${Date.now()}`;
      const pA = await createTestProduct(a.shopId, {
        name: `${tag} A`,
        isPublished: true,
      });
      const pB = await createTestProduct(b.shopId, {
        name: `${tag} B`,
        isPublished: true,
      });
      const res = await request(app)
        .post('/search')
        .send({ q: tag.toLowerCase(), filters: { shopId: a.shopId } });
      expect(res.status).toBe(200);
      const ids = res.body.results.map((r: { id: number }) => r.id);
      expect(ids).toContain(pA.id);
      expect(ids).not.toContain(pB.id);
    } finally {
      await prisma.searchEvent.deleteMany({
        where: { userId: { in: [a.userId, b.userId] } },
      });
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });

  // Semantic + hybrid: with OLLAMA_KEY unset (the default in CI) the
  // response should still come back successfully but the `semantic`
  // flag must be `false`, signalling that the FTS-only path was
  // taken. This is the "graceful degradation" guarantee every other
  // call site relies on.
  it('falls back to FTS-only when OLLAMA_KEY is missing', async () => {
    const previous = process.env.OLLAMA_KEY;
    delete process.env.OLLAMA_KEY;
    const merchant = await createTestUser();
    try {
      const tag = `FtsOnly${Date.now()}`;
      await createTestProduct(merchant.shopId, {
        name: tag,
        isPublished: true,
      });
      const res = await request(app)
        .post('/search')
        .send({ q: tag.toLowerCase() });
      expect(res.status).toBe(200);
      expect(res.body.semantic).toBe(false);
      expect(res.body.results.length).toBeGreaterThanOrEqual(1);
      // Every result row from FTS path carries a `rank` but never
      // a `semanticScore` — the absence is the contract.
      for (const r of res.body.results as Array<{ semanticScore?: number }>) {
        expect(r.semanticScore).toBeUndefined();
      }
    } finally {
      if (previous !== undefined) process.env.OLLAMA_KEY = previous;
      await prisma.searchEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('logs a SearchEvent + upserts SearchTerm', async () => {
    const merchant = await createTestUser();
    try {
      const tag = `Loggable${Date.now()}`;
      await createTestProduct(merchant.shopId, {
        name: tag,
        isPublished: true,
      });
      await request(app).post('/search').send({ q: tag.toLowerCase() });
      await request(app).post('/search').send({ q: tag.toLowerCase() });

      const term = await prisma.searchTerm.findUnique({
        where: { term: tag.toLowerCase() },
      });
      expect(term).not.toBeNull();
      expect(term!.queryCount).toBeGreaterThanOrEqual(2);

      const events = await prisma.searchEvent.findMany({
        where: { query: tag.toLowerCase() },
      });
      expect(events.length).toBeGreaterThanOrEqual(2);
    } finally {
      // Only clean rows this test created — bulk-delete would race
      // with concurrent search tests running in parallel files.
      await prisma.searchEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });
});

describe('search — autocomplete + hints', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });
  afterAll(async () => {
    await clearHintsCache();
    await closeRedis();
    await prisma.$disconnect();
  });

  it('autocomplete returns product hits + matching prior terms', async () => {
    const merchant = await createTestUser();
    try {
      const tag = `Earphone${Date.now()}`;
      await createTestProduct(merchant.shopId, {
        name: tag,
        isPublished: true,
      });
      // Seed a prior search term that should also surface in `terms`.
      await prisma.searchTerm.create({
        data: { term: tag.toLowerCase(), queryCount: 5 },
      });
      const res = await request(app).get(
        `/search/autocomplete?q=${tag.toLowerCase()}`,
      );
      expect(res.status).toBe(200);
      expect(res.body.products.length).toBeGreaterThanOrEqual(1);
      expect(
        res.body.terms.find((t: { term: string }) => t.term === tag.toLowerCase()),
      ).toBeTruthy();
    } finally {
      // Only clean rows this test created — bulk-delete would race
      // with concurrent search tests running in parallel files.
      await prisma.searchEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('hints surface our recent term among the top results', async () => {
    const merchant = await createTestUser();
    const term = `topsaree-${Date.now()}`;
    try {
      await clearHintsCache();
      // Use a very high queryCount so our term lands in the top 10
      // regardless of whatever else other parallel tests inserted.
      await prisma.searchTerm.create({
        data: {
          term,
          queryCount: 9_999,
          lastSearchedAt: new Date(),
        },
      });
      const res = await request(app).get('/search/hints');
      expect(res.status).toBe(200);
      const terms = (res.body.data as Array<{ term: string }>).map((t) => t.term);
      expect(terms).toContain(term);
    } finally {
      await prisma.searchTerm.deleteMany({ where: { term } });
      await cleanupTestUser(merchant);
    }
  });
});

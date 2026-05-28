/// Redis-backed cache for the endless-scroll product feed.
///
/// Two helpers:
///   - getShuffledIds(bucketSeed)          → ordered ids for a single shuffle bucket
///   - getViewerOwnedProductIds(userId)    → product ids the viewer owns (filtered out of their feed)
///
/// Why bucket the seed? Each unique seed costs one full id-list build
/// (one SELECT, one shuffle, one Redis SET). Bounding the seed space
/// to a small number of buckets (default 256) keeps the working set
/// tiny — every concurrent user lands on one of N pre-baked shuffles
/// instead of forcing N+1 builds per session. Different bucket =
/// different ordering, so the user-visible randomness still holds.
///
/// Falls back to direct DB queries when Redis is unavailable so the
/// dev environment (no Redis configured) keeps working.

import { getRedis, redisAvailable } from '../../infra/redis.js';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

const SHUFFLE_TTL_SECONDS = 600;       // 10 min — catalog edits propagate within this window
const OWNED_TTL_SECONDS = 300;         // 5 min — owner-list is stable enough
export const SEED_BUCKETS = 256;       // number of distinct shuffles we maintain

const shuffleKey = (bucket: number) => `mkt:endless:ids:${bucket}`;
const ownedKey = (userId: number) => `mkt:endless:owned:${userId}`;

/// Returns the canonical product id list for a given shuffle bucket
/// (already ordered for the endless feed; pagination is just a slice).
///
/// Cache flow:
///   1. Try Redis GET — JSON-decode, return.
///   2. On miss / Redis unavailable: SELECT all active+published product ids,
///      sort by md5(id || bucketSeed), write back to Redis with TTL.
///
/// Single Postgres hit per (bucket, TTL window). Returns plain numbers
/// so the caller can slice / filter without touching the DB again.
export async function getShuffledIds(bucket: number): Promise<number[]> {
  const key = shuffleKey(bucket);

  if (redisAvailable()) {
    try {
      const cached = await getRedis().get(key);
      if (cached) return JSON.parse(cached) as number[];
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'endless-cache: redis read failed');
    }
  }

  // Cache miss → compute the shuffle. md5(id||seed) is a uniform hash
  // so the sort is statistically uniform and stable per bucket.
  const rows = await prisma.$queryRaw<Array<{ id: number }>>`
    SELECT id FROM products
    WHERE is_active = true AND is_published = true
    ORDER BY md5(id::text || ${String(bucket)})
  `;
  const ids = rows.map((r) => r.id);

  if (redisAvailable()) {
    try {
      await getRedis().set(
        key,
        JSON.stringify(ids),
        'EX',
        SHUFFLE_TTL_SECONDS,
      );
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'endless-cache: redis write failed');
    }
  }

  return ids;
}

/// Returns the set of product ids the viewer's own shop publishes.
/// The endless feed filters these out so a merchant browsing their
/// own home tab doesn't see their own SKUs in the discovery rail.
///
/// Cached per userId with a 5-min TTL — owners don't add/remove
/// products that fast, and a brief lag in the filter is harmless.
export async function getViewerOwnedProductIds(userId: number): Promise<Set<number>> {
  const key = ownedKey(userId);

  if (redisAvailable()) {
    try {
      const cached = await getRedis().get(key);
      if (cached) return new Set(JSON.parse(cached) as number[]);
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'endless-cache: owned read failed');
    }
  }

  const rows = await prisma.product.findMany({
    where: { shop: { ownerUserId: userId } },
    select: { id: true },
  });
  const ids = rows.map((r) => r.id);

  if (redisAvailable()) {
    try {
      await getRedis().set(
        key,
        JSON.stringify(ids),
        'EX',
        OWNED_TTL_SECONDS,
      );
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'endless-cache: owned write failed');
    }
  }

  return new Set(ids);
}

/// Best-effort cache busting — called from product create/update/delete
/// paths to keep stale shuffle lists from sticking around for the full
/// TTL after a catalog mutation. Safe to call when Redis is unavailable.
export async function invalidateShuffleCache(): Promise<void> {
  if (!redisAvailable()) return;
  try {
    const keys = Array.from({ length: SEED_BUCKETS }, (_, i) => shuffleKey(i));
    await getRedis().del(...keys);
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'endless-cache: invalidate failed');
  }
}

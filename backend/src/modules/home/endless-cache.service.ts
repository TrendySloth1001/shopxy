import { getRedis, redisAvailable } from '../../infra/redis.js';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

const SHUFFLE_TTL_SECONDS = 600;
const OWNED_TTL_SECONDS = 300;
export const SEED_BUCKETS = 256;

const shuffleKey = (bucket: number) => `mkt:endless:ids:${bucket}`;
const ownedKey = (userId: number) => `mkt:endless:owned:${userId}`;

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

  const rows = await prisma.$queryRaw<Array<{ id: number }>>`
    SELECT p.id FROM products p
    JOIN shops s ON s.id = p.shop_id
    WHERE p.is_active = true AND p.is_published = true AND s.is_published = true
    ORDER BY md5(p.id::text || ${String(bucket)})
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

export async function invalidateShuffleCache(): Promise<void> {
  if (!redisAvailable()) return;
  try {
    const keys = Array.from({ length: SEED_BUCKETS }, (_, i) => shuffleKey(i));
    await getRedis().del(...keys);
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'endless-cache: invalidate failed');
  }
}

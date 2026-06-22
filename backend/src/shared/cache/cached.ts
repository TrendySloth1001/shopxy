import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../logging/logger.js';

/// Read-through cache with in-process single-flight.
///
/// 1. Try Redis — JSON-decode and return on hit.
/// 2. On miss, collapse concurrent callers for the SAME key in this process to a
///    single `compute()` (the single-flight map). This is the key protection
///    against a thundering herd: when a hot key expires and 1000 requests arrive
///    at once, only ONE hits the DB; the rest await the same promise.
/// 3. Write the result back with a TTL.
///
/// Degrades open: if Redis is unavailable, single-flight still de-dupes
/// concurrent work per process, and correctness is preserved (just no caching).

const inflight = new Map<string, Promise<unknown>>();

export async function cached<T>(key: string, ttlSeconds: number, compute: () => Promise<T>): Promise<T> {
  if (redisAvailable()) {
    try {
      const hit = await getRedis().get(key);
      if (hit !== null) return JSON.parse(hit) as T;
    } catch (err) {
      logger.warn({ err: (err as Error).message, key }, 'cache read failed');
    }
  }

  const existing = inflight.get(key) as Promise<T> | undefined;
  if (existing) return existing;

  const p = (async () => {
    const value = await compute();
    if (redisAvailable()) {
      try {
        await getRedis().set(key, JSON.stringify(value), 'EX', ttlSeconds);
      } catch (err) {
        logger.warn({ err: (err as Error).message, key }, 'cache write failed');
      }
    }
    return value;
  })();

  inflight.set(key, p);
  try {
    return await p;
  } finally {
    inflight.delete(key);
  }
}

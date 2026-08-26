import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../logging/logger.js';

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

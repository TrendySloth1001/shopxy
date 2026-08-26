import Redis, { type RedisOptions } from 'ioredis';
import { logger } from '../shared/logging/logger.js';

function buildClient(): Redis {
  const url = process.env.REDIS_URL;
  const lazyOpts: RedisOptions = {
    lazyConnect: true,
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
  };
  if (url) return new Redis(url, lazyOpts);
  return new Redis({
    host: process.env.REDIS_HOST ?? 'localhost',
    port: Number(process.env.REDIS_PORT ?? 6379),
    ...lazyOpts,
  });
}

const client = buildClient();

let available = false;
let connectAttempted = false;

client.on('error', (err) => {
  if (available) {
    logger.warn({ err: err.message }, 'redis connection lost');
    available = false;
  }
});

export async function pingRedis(timeoutMs = 1500): Promise<boolean> {
  if (connectAttempted) return available;
  connectAttempted = true;
  try {
    await Promise.race([
      client.connect().then(() => client.ping()),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('redis ping timeout')), timeoutMs),
      ),
    ]);
    available = true;
    logger.info('redis connected');
    return true;
  } catch (err) {
    available = false;
    logger.warn({ err: (err as Error).message }, 'redis unavailable — caches disabled');
    return false;
  }
}

export function redisAvailable(): boolean {
  return available;
}

export function getRedis(): Redis {
  return client;
}

export async function tryAcquireJobLock(key: string, ttlMs: number): Promise<boolean> {
  if (!available) return true;
  try {
    const res = await client.set(`lock:${key}`, '1', 'PX', ttlMs, 'NX');
    return res === 'OK';
  } catch (err) {
    logger.warn({ err: (err as Error).message, key }, 'job lock check failed — running anyway');
    return true;
  }
}

export async function closeRedis(): Promise<void> {
  if (available) {
    try {
      await client.quit();
    } catch {
      client.disconnect();
    }
  }
  available = false;
}

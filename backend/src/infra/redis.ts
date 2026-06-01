import Redis, { type RedisOptions } from 'ioredis';
import { logger } from '../shared/logging/logger.js';

/// Redis client used for hot caches (home-feed, banner lookups,
/// trending scores) and atomic counters (flash-deal sold counter).
///
/// Connection strategy: configured via REDIS_URL (e.g. `redis://localhost:6379`)
/// or REDIS_HOST + REDIS_PORT. If neither is set we connect to localhost:6379.
///
/// **Graceful degradation**: if the server can't reach Redis at boot,
/// we log a warning and `redisAvailable()` returns false. Cache helpers
/// must check this and fall back to a direct DB read — losing the
/// performance benefit but not the correctness. This keeps local dev
/// frictionless (you don't need Redis up to boot the API) and means
/// a transient Redis outage in prod doesn't take down requests.

function buildClient(): Redis {
  const url = process.env.REDIS_URL;
  const lazyOpts: RedisOptions = {
    // Don't dial on construct — the first command does it. Lets us run
    // a boot-time PING with a controlled timeout instead of ioredis's
    // unbounded reconnect storm during the first 30s of dev startup.
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
  // Throttle: once we know it's down, no need to spam.
  if (available) {
    logger.warn({ err: err.message }, 'redis connection lost');
    available = false;
  }
});

/// Boot-time probe — call once from server start. Times out fast so a
/// missing Redis doesn't delay the API coming up. Subsequent calls to
/// `redisAvailable()` reflect the latest known state (the `error`
/// handler above flips it back to false if Redis disappears mid-flight).
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

/// Best-effort single-runner lock (atomic SET NX PX). Used by scheduled jobs
/// that call a rate-limited EXTERNAL API (e.g. gateway reconciliation polling
/// Razorpay) so multiple app instances don't all fire the same sweep at once.
///
/// This is NOT a correctness primitive — every job it guards is idempotent, so
/// a lost lock at worst means redundant external calls, never a double-write.
/// It therefore **degrades open**: if Redis is unreachable we return true (run
/// anyway), because a single-instance/dev box has no contention and the job
/// must not hinge on Redis being up. The TTL auto-expires the lock so a crash
/// between acquire and the next tick can't wedge the job permanently.
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

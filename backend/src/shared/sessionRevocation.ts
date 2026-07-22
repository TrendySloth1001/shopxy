import { getRedis, redisAvailable } from '../infra/redis.js';
import { logger } from './logging/logger.js';

/**
 * Instant per-session logout for the otherwise-stateless access token.
 *
 * Each access token carries a session id (`sid` = its refresh-token family).
 * A single-device logout revokes that `sid` here, and `requireAuth` rejects any
 * access token whose `sid` is revoked — closing the up-to-15-minute window a
 * stolen access token would otherwise survive after logout. (`logout-all` still
 * uses the `tokensValidFrom` floor to nuke *every* session at once.)
 *
 * **Optimised for the hot path**: the per-request check is a single in-memory
 * Map lookup — no Redis round-trip on requests. Revocations fan out to other
 * instances over Redis pub/sub and are seeded from Redis at boot so a restart
 * doesn't forget them. Entries self-expire after the access-token lifetime, so
 * the set only ever holds sessions logged out in the last 15 minutes.
 *
 * **Fail-open**: if Redis is down, revocation is local to this instance (still
 * correct single-instance); it never blocks a request.
 */

const CHANNEL = 'auth:revoke';
const KEY_PREFIX = 'authrev:';
const TTL_S = 15 * 60; // == access-token lifetime; after this the token expires anyway

// sid -> epoch ms after which the entry is meaningless (its access token is dead).
const revoked = new Map<string, number>();

function remember(sid: string): void {
  revoked.set(sid, Date.now() + TTL_S * 1000);
}

/** O(1) hot-path check used by requireAuth on every request. Purges lazily. */
export function isSessionRevoked(sid: string): boolean {
  const exp = revoked.get(sid);
  if (exp === undefined) return false;
  if (exp <= Date.now()) {
    revoked.delete(sid);
    return false;
  }
  return true;
}

/** Revoke a session everywhere: locally, in Redis (restart-safe), to peers. */
export async function revokeSession(sid: string): Promise<void> {
  remember(sid);
  if (!redisAvailable()) return;
  try {
    const r = getRedis();
    await r.set(KEY_PREFIX + sid, '1', 'EX', TTL_S);
    await r.publish(CHANNEL, sid);
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'session revoke: redis propagation failed');
  }
}

/**
 * Boot-time wiring (mirrors SaleBus): seed the local set from live revocations
 * so a fresh instance honours logouts that happened while it was down, then
 * subscribe so peer revocations land in-memory for the O(1) request check.
 */
class SessionRevocationBus {
  private subscriber?: ReturnType<typeof getRedis>;

  async init(): Promise<void> {
    if (!redisAvailable()) return;
    try {
      const r = getRedis();
      // Seed from any still-live revocations (survives a restart). SCAN, not
      // KEYS, so a large keyspace can't stall the boot; the matched set is
      // tiny (only the last 15 min of logouts).
      let cursor = '0';
      do {
        const [next, keys] = await r.scan(cursor, 'MATCH', `${KEY_PREFIX}*`, 'COUNT', 200);
        cursor = next;
        for (const k of keys) remember(k.slice(KEY_PREFIX.length));
      } while (cursor !== '0');

      // Dedicated subscriber connection (see SaleBus for why the offline queue
      // must be enabled on the duplicate).
      const sub = r.duplicate({ enableOfflineQueue: true });
      sub.on('error', (err: Error) =>
        logger.warn({ err: err.message }, 'auth: session-revocation subscriber error'),
      );
      sub.on('message', (_channel: string, sid: string) => remember(sid));
      await sub.subscribe(CHANNEL);
      this.subscriber = sub;
      logger.info('auth: session revocation using Redis pub/sub (multi-instance)');
    } catch (err) {
      logger.warn({ err }, 'auth: session-revocation init failed; local-only');
    }
  }

  async close(): Promise<void> {
    if (this.subscriber) {
      await this.subscriber.quit().catch(() => undefined);
      this.subscriber = undefined;
    }
  }
}

export const sessionRevocationBus = new SessionRevocationBus();

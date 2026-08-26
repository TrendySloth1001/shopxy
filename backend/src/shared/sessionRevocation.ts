import { getRedis, redisAvailable } from '../infra/redis.js';
import { logger } from './logging/logger.js';

const CHANNEL = 'auth:revoke';
const KEY_PREFIX = 'authrev:';
const TTL_S = 15 * 60;

const revoked = new Map<string, number>();

function remember(sid: string): void {
  revoked.set(sid, Date.now() + TTL_S * 1000);
}

export function isSessionRevoked(sid: string): boolean {
  const exp = revoked.get(sid);
  if (exp === undefined) return false;
  if (exp <= Date.now()) {
    revoked.delete(sid);
    return false;
  }
  return true;
}

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

class SessionRevocationBus {
  private subscriber?: ReturnType<typeof getRedis>;

  async init(): Promise<void> {
    if (!redisAvailable()) return;
    try {
      const r = getRedis();
      let cursor = '0';
      do {
        const [next, keys] = await r.scan(cursor, 'MATCH', `${KEY_PREFIX}*`, 'COUNT', 200);
        cursor = next;
        for (const k of keys) remember(k.slice(KEY_PREFIX.length));
      } while (cursor !== '0');

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

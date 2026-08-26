import { createHash } from 'crypto';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

const THRESHOLD = 5;
const FAIL_WINDOW_S = 15 * 60;
const BASE_LOCK_S = 60;
const MAX_LOCK_S = 30 * 60;
const TIER_TTL_S = 24 * 60 * 60;

const keyFail = (id: string) => `authlock:fail:${id}`;
const keyTier = (id: string) => `authlock:tier:${id}`;
const keyUntil = (id: string) => `authlock:until:${id}`;

function accountId(email: string): string {
  return createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

export async function loginLockRemainingMs(email: string): Promise<number> {
  if (!redisAvailable()) return 0;
  try {
    const ttl = await getRedis().pttl(keyUntil(accountId(email)));
    return ttl > 0 ? ttl : 0;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'login lock check failed — allowing');
    return 0;
  }
}

export async function recordLoginFailure(email: string): Promise<number> {
  if (!redisAvailable()) return 0;
  const id = accountId(email);
  try {
    const r = getRedis();
    const fails = await r.incr(keyFail(id));
    if (fails === 1) await r.expire(keyFail(id), FAIL_WINDOW_S);
    if (fails < THRESHOLD) return 0;

    const tier = await r.incr(keyTier(id));
    await r.expire(keyTier(id), TIER_TTL_S);
    const lockS = Math.min(MAX_LOCK_S, BASE_LOCK_S * 2 ** (tier - 1));
    await r.set(keyUntil(id), '1', 'EX', lockS);
    await r.del(keyFail(id));
    return lockS * 1000;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'login failure record failed');
    return 0;
  }
}

export async function clearLoginFailures(email: string): Promise<void> {
  if (!redisAvailable()) return;
  const id = accountId(email);
  try {
    await getRedis().del(keyFail(id), keyTier(id), keyUntil(id));
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'login failure clear failed');
  }
}

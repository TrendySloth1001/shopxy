import { createHash } from 'crypto';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

/**
 * Per-account login throttle — the second line behind the per-IP `/auth` rate
 * limiter. The IP limiter can't stop distributed credential-stuffing (one guess
 * per IP across a botnet); this counts failures **per account** and locks the
 * account with exponential backoff once they pile up.
 *
 * Design notes:
 * - **O(1)**: every path is a couple of atomic Redis ops — no scans, no loops.
 * - **Fail-open**: if Redis is down the checks no-op (the IP limiter still
 *   applies). Failing closed would let a Redis blip lock out every user — a
 *   self-inflicted DoS worse than the brute-force risk it guards.
 * - **DoS-bounded**: locks are capped at {@link MAX_LOCK_S}, and any successful
 *   login clears the escalation, so an attacker can't lock a victim out forever.
 * - **Privacy**: the email is SHA-256'd before it becomes a key, so raw
 *   addresses never sit in Redis.
 */

const THRESHOLD = 5; // failed attempts within the window before a lock kicks in
const FAIL_WINDOW_S = 15 * 60; // how long failures accumulate
const BASE_LOCK_S = 60; // first lock: 1 minute
const MAX_LOCK_S = 30 * 60; // cap: 30 minutes
const TIER_TTL_S = 24 * 60 * 60; // how long the escalation level is remembered

const keyFail = (id: string) => `authlock:fail:${id}`;
const keyTier = (id: string) => `authlock:tier:${id}`;
const keyUntil = (id: string) => `authlock:until:${id}`;

function accountId(email: string): string {
  return createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

/** Remaining lock time in ms (0 = not locked). Fail-open on Redis errors. */
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

/**
 * Record one failed attempt, escalating into a lock once the threshold is hit.
 * Returns the lock duration in ms when this call *causes* a lock, else 0.
 */
export async function recordLoginFailure(email: string): Promise<number> {
  if (!redisAvailable()) return 0;
  const id = accountId(email);
  try {
    const r = getRedis();
    const fails = await r.incr(keyFail(id));
    if (fails === 1) await r.expire(keyFail(id), FAIL_WINDOW_S);
    if (fails < THRESHOLD) return 0;

    // Threshold reached — bump the escalation tier and lock with backoff.
    const tier = await r.incr(keyTier(id));
    await r.expire(keyTier(id), TIER_TTL_S);
    const lockS = Math.min(MAX_LOCK_S, BASE_LOCK_S * 2 ** (tier - 1));
    await r.set(keyUntil(id), '1', 'EX', lockS);
    // Reset the counter so the next lock needs a fresh run of failures.
    await r.del(keyFail(id));
    return lockS * 1000;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'login failure record failed');
    return 0;
  }
}

/** Clear failures + escalation after a genuine success. Fail-open. */
export async function clearLoginFailures(email: string): Promise<void> {
  if (!redisAvailable()) return;
  const id = accountId(email);
  try {
    await getRedis().del(keyFail(id), keyTier(id), keyUntil(id));
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'login failure clear failed');
  }
}

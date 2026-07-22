import { createHash } from 'crypto';
import { logger } from '../../shared/logging/logger.js';

/**
 * Reject passwords that appear in known breach corpora, via Have I Been Pwned's
 * range API using **k-anonymity**: we send only the first 5 hex chars of the
 * password's SHA-1 and match the returned suffixes locally, so the full hash
 * (let alone the password) never leaves the server.
 *
 * - **Fail-open**: if HIBP is unreachable/slow we allow the password rather than
 *   block a signup on a third-party outage. The strength regex + bcrypt still
 *   apply; this is an *additional* gate, not the only one.
 * - **Bounded**: one HTTPS GET with a short timeout; the response is a small
 *   text list we scan once.
 */

const HIBP_RANGE_URL = 'https://api.pwnedpasswords.com/range/';
const TIMEOUT_MS = 2500;

export async function isPasswordBreached(password: string): Promise<boolean> {
  const sha1 = createHash('sha1').update(password).digest('hex').toUpperCase();
  const prefix = sha1.slice(0, 5);
  const suffix = sha1.slice(5);

  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    let body: string;
    try {
      const res = await fetch(`${HIBP_RANGE_URL}${prefix}`, {
        headers: { 'Add-Padding': 'true' },
        signal: controller.signal,
      });
      if (!res.ok) return false; // treat a non-200 as "unknown" → allow
      body = await res.text();
    } finally {
      clearTimeout(timer);
    }

    // Each line is "<SHA1_SUFFIX>:<count>". A count > 0 means it's a real hit
    // (padding rows are appended with a count of 0).
    for (const line of body.split('\n')) {
      const sep = line.indexOf(':');
      if (sep === -1) continue;
      if (line.slice(0, sep).trim() === suffix) {
        return Number(line.slice(sep + 1)) > 0;
      }
    }
    return false;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'HIBP check failed — allowing password');
    return false;
  }
}

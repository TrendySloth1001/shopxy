import { createHash } from 'crypto';
import { logger } from '../../shared/logging/logger.js';

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
      if (!res.ok) return false;
      body = await res.text();
    } finally {
      clearTimeout(timer);
    }

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

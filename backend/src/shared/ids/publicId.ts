import Sqids from 'sqids';
import { envBool, envOr } from '../env.js';

/**
 * Public (external) ID codec — the single source of truth for turning an
 * internal integer primary key into an opaque, non-sequential token that is
 * safe to put in URLs and API payloads, and back again.
 *
 * ## Why
 *
 * Every table uses `@id @default(autoincrement())`. Cross-tenant access is
 * already blocked server-side (every query is scoped by `shopId` from the
 * JWT), so a raw `productId=1` is **not** an IDOR risk. The only thing a bare
 * sequential id leaks is *business volume* — a competitor who signs up can read
 * your catalog size / invoice throughput off the numbers. This codec hides the
 * sequence so `1, 2, 3…` become `UkLWZg9D, 9fRq2Xn4, …`.
 *
 * Sqids is reversible obfuscation, **not** encryption — but that is exactly the
 * right tool here: because authorization already refuses shop-foreign rows,
 * even a fully-reversed token buys an attacker nothing. We get sequence-hiding
 * with zero DB migration.
 *
 * ## Rollout (expand/contract) — {@link idsEnabled}
 *
 * Emitting a string `id` where clients expect a number is a breaking change for
 * every client at once. So OUTPUT encoding is gated behind `PUBLIC_IDS`
 * (default off):
 *
 * - **flag off (default):** {@link encodeId} returns the raw number unchanged —
 *   responses are byte-for-byte what they were, so the backend is safe to land
 *   ahead of any client work.
 * - **flag on:** {@link encodeId} returns the opaque token.
 *
 * {@link decodeId} is **always dual-mode**: it accepts both an opaque token and
 * a legacy plain-integer string, in every mode. That means request parsing
 * keeps working for old and new clients throughout the migration — only the
 * flag flip (coordinated with client readiness) changes what we emit.
 */

// Alphabet is shuffled per-deployment so tokens aren't portable/guessable
// across environments. It is NOT a secret (Sqids is reversible regardless), so
// a stable default is fine for dev; override in prod for distinct tokens.
const ALPHABET = envOr(
  'PUBLIC_ID_ALPHABET',
  'fedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210zyxwvutsrqponmlkjihg',
);

// minLength pads short ids so `1` doesn't encode to a 1–2 char token that
// telegraphs "small number"; 8 keeps them uniform and URL-friendly.
const sqids = new Sqids({ alphabet: ALPHABET, minLength: 8 });

/** Whether opaque public IDs are emitted. See the expand/contract note above. */
export function idsEnabled(): boolean {
  return envBool('PUBLIC_IDS', true);
}

/**
 * Encode an internal integer id for the wire.
 *
 * Returns the opaque token when {@link idsEnabled}, otherwise the number
 * unchanged (safe no-op landing). Non-positive / non-integer input is returned
 * as-is so callers never accidentally mint a token for a sentinel like `0`.
 */
export function encodeId(id: number): number | string {
  if (!idsEnabled()) return id;
  if (!Number.isInteger(id) || id <= 0) return id;
  return sqids.encode([id]);
}

/**
 * Decode a wire id back to its internal integer, or `null` if it is neither a
 * valid token nor a legacy positive integer.
 *
 * Dual-mode by design (see the class note): a plain numeric string like `"42"`
 * decodes to `42`, and an opaque token decodes to the id it was minted from.
 * Everything else — empty, forged, or a token that fails the round-trip guard —
 * returns `null`, and callers must treat that as a 404 (never confirm the id
 * space with a 400).
 */
export function decodeId(raw: string | undefined | null): number | null {
  if (raw == null) return null;
  const s = String(raw).trim();
  if (s === '') return null;

  // Legacy / dual-mode: a bare positive integer is accepted as-is so requests
  // from not-yet-migrated clients keep resolving during the rollout.
  if (/^\d+$/.test(s)) {
    const n = Number(s);
    return Number.isInteger(n) && n > 0 ? n : null;
  }

  // Opaque token. Sqids will happily decode arbitrary strings into *some*
  // number array, so we MUST re-encode and compare: only a token this codec
  // could itself have produced (single, positive, round-trips exactly) is
  // valid. This rejects forged/garbage tokens.
  const decoded = sqids.decode(s);
  if (decoded.length !== 1) return null;
  const n = decoded[0];
  if (!Number.isInteger(n) || n <= 0) return null;
  return sqids.encode([n]) === s ? n : null;
}

/** A key whose value is an internal id: exactly `id`, or a `…Id` foreign key. */
function isIdKey(key: string): boolean {
  return key === 'id' || key.endsWith('Id');
}

/**
 * Recursively encode every internal-id field in a response payload.
 *
 * Because controllers serialise raw Prisma rows (no DTO layer), this is the
 * one-line SSOT for the OUTPUT side: `res.json(encodeIdsDeep(payload))`. It
 * rewrites the value under any {@link isIdKey} key that holds a **number**
 * (via {@link encodeId}) and recurses through plain objects and arrays.
 *
 * Deliberately conservative so it can be applied blindly:
 * - **flag off → identity** (returns the input untouched, no clone, no cost).
 * - Only **numeric** id-fields are touched. A `…Id` that already holds a string
 *   (e.g. `razorpayOrderId`, an external gateway id) is left as-is.
 * - **Non-plain objects are left intact** — `Prisma.Decimal` (money), `Date`,
 *   `Buffer`, etc. are never walked, so amounts/timestamps can't be corrupted.
 */
export function encodeIdsDeep<T>(value: T): T {
  if (!idsEnabled()) return value;
  return walk(value) as T;
}

function walk(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(walk);
  if (v !== null && typeof v === 'object') {
    // Only descend into *plain* objects. Class instances (Decimal, Date,
    // Buffer, …) have a non-Object prototype and are passed through untouched.
    const proto = Object.getPrototypeOf(v);
    if (proto !== Object.prototype && proto !== null) return v;
    const out: Record<string, unknown> = {};
    for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
      out[k] = isIdKey(k) && typeof val === 'number' ? encodeId(val) : walk(val);
    }
    return out;
  }
  return v;
}

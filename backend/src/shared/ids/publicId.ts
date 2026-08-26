import Sqids from 'sqids';
import { envBool, envOr } from '../env.js';

const ALPHABET = envOr(
  'PUBLIC_ID_ALPHABET',
  'fedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210zyxwvutsrqponmlkjihg',
);

const sqids = new Sqids({ alphabet: ALPHABET, minLength: 8 });

export function idsEnabled(): boolean {
  return envBool('PUBLIC_IDS', true);
}

export function encodeId(id: number): number | string {
  if (!idsEnabled()) return id;
  if (!Number.isInteger(id) || id <= 0) return id;
  return sqids.encode([id]);
}

export function decodeId(raw: string | undefined | null): number | null {
  if (raw == null) return null;
  const s = String(raw).trim();
  if (s === '') return null;

  if (/^\d+$/.test(s)) {
    const n = Number(s);
    return Number.isInteger(n) && n > 0 ? n : null;
  }

  const decoded = sqids.decode(s);
  if (decoded.length !== 1) return null;
  const n = decoded[0];
  if (!Number.isInteger(n) || n <= 0) return null;
  return sqids.encode([n]) === s ? n : null;
}

function isIdKey(key: string): boolean {
  return key === 'id' || key.endsWith('Id');
}

export function encodeIdsDeep<T>(value: T): T {
  if (!idsEnabled()) return value;
  return walk(value) as T;
}

function walk(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(walk);
  if (v !== null && typeof v === 'object') {
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

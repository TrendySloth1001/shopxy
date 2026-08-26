export type CtaTargetKind = 'category' | 'product' | 'collection' | 'url';

export interface CtaTarget {
  kind: CtaTargetKind;
  value: string;
}

export const MAX_CTA_TARGET_LENGTH = 2048;

export function parseCtaTarget(raw: string): CtaTarget | null {
  if (typeof raw !== 'string' || raw.length === 0) return null;
  if (raw.length > MAX_CTA_TARGET_LENGTH) return null;

  const idx = raw.indexOf(':');
  if (idx <= 0) return null;
  const kind = raw.slice(0, idx);
  const value = raw.slice(idx + 1);
  if (!value) return null;

  switch (kind) {
    case 'category':
    case 'collection':
      if (!/^[a-z0-9-]{1,80}$/.test(value)) return null;
      return { kind, value };
    case 'product':
      if (!/^[0-9]{1,18}$/.test(value)) return null;
      return { kind, value };
    case 'url': {
      try {
        const u = new URL(value);
        if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
      } catch {
        return null;
      }
      return { kind: 'url', value };
    }
    default:
      return null;
  }
}

export function isValidCtaTarget(raw: string): boolean {
  return parseCtaTarget(raw) !== null;
}

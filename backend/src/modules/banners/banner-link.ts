export const BANNER_LINK_KINDS = [
  'product',
  'category',
  'shop',
  'search',
] as const;

export type BannerLinkKind = (typeof BANNER_LINK_KINDS)[number];

export interface BannerLink {
  kind: BannerLinkKind;
  value: string;
}

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const PUBLIC_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

const MAX_SEARCH_LENGTH = 120;

export function parseBannerLink(
  raw: string | null | undefined,
): BannerLink | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  const separator = trimmed.indexOf(':');
  if (separator <= 0) return null;

  const kind = trimmed.slice(0, separator).toLowerCase();
  const value = trimmed.slice(separator + 1).trim();
  if (value.length === 0) return null;

  switch (kind) {
    case 'product':
      return PUBLIC_ID_RE.test(value) ? { kind: 'product', value } : null;
    case 'category':
    case 'shop':
      return SLUG_RE.test(value.toLowerCase())
        ? { kind, value: value.toLowerCase() }
        : null;
    case 'search':
      return value.length <= MAX_SEARCH_LENGTH
        ? { kind: 'search', value }
        : null;
    default:
      return null;
  }
}

export function formatBannerLink(link: BannerLink): string {
  return `${link.kind}:${link.value}`;
}

export const BANNER_LINK_HELP =
  'A banner link must be one of product:<id>, category:<slug>, ' +
  'shop:<slug> or search:<words>.';

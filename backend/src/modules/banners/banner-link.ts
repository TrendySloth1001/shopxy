/**
 * Where a banner sends you when it's tapped.
 *
 * This exists because the banner link was broken in three mutually
 * contradictory ways at once:
 *
 *   * the merchant editor's helper text documented `category:slug`,
 *     `product:id` and `url:https://…`;
 *   * the API's validator accepted only `https://…` or a leading `/`, so
 *     every documented format was rejected with a 400;
 *   * the customer app resolved neither — a stored link was passed to the
 *     search box as a literal query string, so `https://x` searched for the
 *     text "https://x" and `/shop/acme` opened an empty search.
 *
 * The result was that no banner link could ever work. This module is the one
 * definition of the grammar, shared by the validator, the merchant editor and
 * the customer resolver, so the three cannot drift apart again.
 *
 * Grammar — `<kind>:<value>`:
 *   product:<publicId>   a single product's detail page
 *   category:<slug>      a category listing
 *   shop:<slug>          a seller's storefront
 *   search:<query>       the search results for a phrase
 *
 * External `https://` targets are deliberately NOT in the grammar. The
 * customer app has no browser affordance, so an off-platform link would have
 * nowhere to go — better to reject it on save than to store a link that
 * silently does nothing.
 */

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

/// Slugs are what the URL-facing tables actually store: lower-case
/// alphanumerics and hyphens.
const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/// Opaque public ids (Sqids) are alphanumeric; a raw numeric id is accepted
/// too so the grammar keeps working with PUBLIC_IDS off.
const PUBLIC_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

const MAX_SEARCH_LENGTH = 120;

/// Parses a stored link. Returns null for anything unrecognised — including
/// the legacy `https://…` and `/path` values written before this grammar
/// existed — so a client can treat "no usable link" as decorative rather than
/// guessing at a destination.
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
      // Slugs are canonically lower-case; accept a typed upper-case one
      // rather than failing a merchant over capitalisation.
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

/// Human-readable reason a link was rejected, for the API's 400 body. Kept
/// here so the message names the same grammar the parser enforces.
export const BANNER_LINK_HELP =
  'A banner link must be one of product:<id>, category:<slug>, ' +
  'shop:<slug> or search:<words>.';

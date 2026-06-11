/**
 * Resolve a backend-supplied image reference to a renderable src.
 *
 * Product/shop imagery is merchant-supplied and comes in two shapes:
 *  - absolute https URLs (e.g. Unsplash seeds, external CDNs) — use as-is;
 *  - backend-relative keys ("/images/<key>") — served through the same-origin
 *    /api/media proxy so API_BASE_URL stays server-only.
 *
 * Prefixing /api/media onto an absolute URL produces a guaranteed 404 — that
 * was the broken-thumbnail bug on checkout/orders. Always go through here.
 */
export function mediaSrc(url: string | null | undefined): string | null {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  return `/api/media/${url.replace(/^\//, "")}`;
}

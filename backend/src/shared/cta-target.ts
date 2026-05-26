/// Banner / collection CTAs encode their target as a tiny string DSL so
/// the same field handles all four flavours without bespoke columns:
///
///   category:<slug>     → /category/:slug listing
///   product:<id>        → /product/:id PDP
///   collection:<slug>   → editorial collection (Phase 4)
///   url:https://…       → arbitrary external destination
///
/// Validated server-side at write time (banners.service) and parsed
/// client-side when the customer taps. Keeping it as text avoids a
/// polymorphic FK or four separate nullable columns.

export type CtaTargetKind = 'category' | 'product' | 'collection' | 'url';

export interface CtaTarget {
  kind: CtaTargetKind;
  value: string;
}

// Hard cap on accepted input length. The longest legitimate target
// is a url:https://… value where the URL itself is bounded by what a
// banner editor would paste. 2048 chars is generous; anything larger
// is almost certainly an abuse attempt and would force the URL
// constructor / regex engine to do more work than we ever need.
export const MAX_CTA_TARGET_LENGTH = 2048;

/// Strict parser — returns null on any malformed input. Use the
/// boolean `isValidCtaTarget` if you only need yes/no for validation.
///
/// Linear-time by construction: the leading length guard caps every
/// downstream operation (indexOf, slice, the anchored regexes, and
/// the URL constructor) at O(MAX_CTA_TARGET_LENGTH). All regexes are
/// anchored with ^…$ and have no nested quantifiers, so no
/// backtracking explosion is possible.
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
      // Bound the digit run so a 2KB string of digits doesn't get
      // turned into a huge Number downstream.
      if (!/^[0-9]{1,18}$/.test(value)) return null;
      return { kind, value };
    case 'url': {
      try {
        const u = new URL(value);
        // Only http(s); reject javascript: and other URL schemes that
        // could XSS through into the customer's WebView/in-app browser.
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

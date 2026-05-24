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

/// Strict parser — returns null on any malformed input. Use the
/// boolean `isValidCtaTarget` if you only need yes/no for validation.
export function parseCtaTarget(raw: string): CtaTarget | null {
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
      if (!/^\d+$/.test(value)) return null;
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

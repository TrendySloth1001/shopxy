/**
 * Shared device/context helpers for session + login-alert records. Single
 * source of truth for turning a raw request (IP + user-agent) into the
 * recognisable-but-not-precise fields we store and show.
 */

export interface DeviceContext {
  ip?: string | null;
  userAgent?: string | null;
  /// Explicit, human device name from the client (X-Device-Name header), e.g.
  /// "Nikhil's iPhone" / "Pixel 7". Preferred over the UA-parsed label.
  deviceName?: string | null;
}

/** Coarse IP for a recognisable history entry — drops the last octet / v6 tail. */
export function maskIp(ip?: string | null): string | null {
  if (!ip) return null;
  const v = ip.replace(/^::ffff:/, '');
  if (v.includes('.')) return v.split('.').slice(0, 3).join('.') + '.x';
  if (v.includes(':')) {
    // Loopback/link-local shorthand (::1, ::) has nothing left to mask —
    // showing it as-is is clearer than the old code's `::1:…`, which
    // reconstituted the same address plus a nonsensical trailing ellipsis.
    const groups = v.split(':').filter(Boolean);
    if (groups.length <= 1) return v;
    return groups.slice(0, 3).join(':') + ':…';
  }
  return null;
}

/**
 * Best-effort friendly device name from a user-agent, e.g. "Chrome on Windows",
 * "Safari on Mac", "iPhone", "Android app". Falls back to "Unknown device" when
 * the UA is missing/unrecognised (native apps often send a bare `Dart/x` UA).
 */
export function deviceLabel(userAgent?: string | null): string {
  const ua = userAgent ?? '';
  if (!ua) return 'Unknown device';

  // Native app clients first (Flutter/Dart, or an explicit app UA).
  if (/\bShopXY\b/i.test(ua)) {
    if (/iPhone|iOS/i.test(ua)) return 'ShopXY on iPhone';
    if (/iPad/i.test(ua)) return 'ShopXY on iPad';
    if (/Android/i.test(ua)) return 'ShopXY on Android';
    return 'ShopXY app';
  }
  if (/^Dart\//i.test(ua) || /dart:io/i.test(ua)) return 'ShopXY app';

  const os = /iPhone/i.test(ua)
    ? 'iPhone'
    : /iPad/i.test(ua)
      ? 'iPad'
      : /Android/i.test(ua)
        ? 'Android'
        : /Windows/i.test(ua)
          ? 'Windows'
          : /Mac OS X|Macintosh/i.test(ua)
            ? 'Mac'
            : /Linux/i.test(ua)
              ? 'Linux'
              : null;

  // Order matters: Edge/Chrome UAs also contain "Safari"; Chrome contains "Edg".
  const browser = /Edg\//i.test(ua)
    ? 'Edge'
    : /OPR\/|Opera/i.test(ua)
      ? 'Opera'
      : /Firefox\//i.test(ua)
        ? 'Firefox'
        : /Chrome\//i.test(ua)
          ? 'Chrome'
          : /Safari\//i.test(ua)
            ? 'Safari'
            : null;

  if (browser && os) return `${browser} on ${os}`;
  if (os) return os;
  if (browser) return browser;
  return 'Unknown device';
}

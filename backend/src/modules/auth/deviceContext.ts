export interface DeviceContext {
  ip?: string | null;
  userAgent?: string | null;
  deviceName?: string | null;
}

export function maskIp(ip?: string | null): string | null {
  if (!ip) return null;
  const v = ip.replace(/^::ffff:/, '');
  if (v.includes('.')) return v.split('.').slice(0, 3).join('.') + '.x';
  if (v.includes(':')) {
    const groups = v.split(':').filter(Boolean);
    if (groups.length <= 1) return v;
    return groups.slice(0, 3).join(':') + ':…';
  }
  return null;
}

export function deviceLabel(userAgent?: string | null): string {
  const ua = userAgent ?? '';
  if (!ua) return 'Unknown device';

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

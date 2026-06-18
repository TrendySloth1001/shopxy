import type { Area } from './permissions.js';

/// Single source of truth: every merchant route prefix → its permission
/// area. `mountMerchant` (in app.ts) throws at boot if a prefix isn't
/// listed here, and the coverage test asserts this map stays in sync with
/// what's actually mounted — so a new merchant route can't ship ungated
/// (fail-closed by construction).
export const MERCHANT_AREAS: Record<string, Area> = {
  '/me/team': 'team',
  '/me/shop': 'shop',
  '/me/banners': 'marketing',
  '/me/scan-console': 'products',
  '/me/pos': 'invoices',
  '/me/analytics': 'reports',
  '/me/coupons-admin': 'marketing',
  '/custom-fields': 'products',
  '/products': 'products',
  '/stock': 'stock',
  '/stock-adjustments': 'stock',
  '/dashboard': 'dashboard',
  '/vendors': 'vendors',
  '/parties': 'parties',
  '/caution-requests': 'invoices',
  '/quotations': 'invoices',
  '/invoices': 'invoices',
  '/challans': 'invoices',
  '/reports': 'reports',
  '/orders/returns': 'orders',
  '/orders': 'orders',
  '/linked-account': 'payouts',
  '/payments': 'payments',
};

/// Merchant mounts intentionally NOT area-gated (open to any team
/// member). Kept explicit so the coverage test can distinguish
/// "deliberately open" from "someone forgot to gate it".
///   • /upload — shared image/file infra used by the product + invoice
///     write flows; the *targets* are already gated, so the raw upload
///     endpoint is low-risk and must stay reachable for every writer.
export const OPEN_MERCHANT_MOUNTS: readonly string[] = ['/upload'];

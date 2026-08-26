import type { Area } from './permissions.js';

export const MERCHANT_AREAS: Record<string, Area> = {
  '/me/team': 'team',
  '/me/shop': 'shop',
  '/me/banners': 'marketing',
  '/me/scan-console': 'products',
  '/me/pos': 'invoices',
  '/me/cashier': 'invoices',
  '/me/coupons-admin': 'marketing',
  '/custom-fields': 'products',
  '/products': 'products',
  '/stock': 'stock',
  '/stock-adjustments': 'stock',
  '/dashboard': 'dashboard',
  '/vendors': 'vendors',
  '/parties': 'parties',
  '/quotations': 'quotations',
  '/invoices': 'invoices',
  '/numbering': 'invoices',
  '/pdf-templates': 'invoices',
  '/challans': 'challans',
  '/reports': 'reports',
  '/orders/returns': 'orders',
  '/orders': 'orders',
  '/linked-account': 'payouts',
  '/payments': 'payments',
};

export const OPEN_MERCHANT_MOUNTS: readonly string[] = ['/upload'];

import { Request, Response, NextFunction } from 'express';
import { ShopRole } from '@prisma/client';

export const AREAS = [
  'dashboard',
  'products',
  'orders',
  'invoices',
  'quotations',
  'challans',
  'payments',
  'parties',
  'stock',
  'vendors',
  'marketing',
  'shop',
  'reports',
  'payouts',
  'team',
] as const;
export type Area = (typeof AREAS)[number];

export type Action = 'view' | 'manage';

const VIEW_ONLY: ReadonlySet<Area> = new Set<Area>(['dashboard', 'reports']);

export function viewRight(area: Area): string {
  return `${area}:view`;
}
export function manageRight(area: Area): string {
  return `${area}:manage`;
}

export const POS_OVERRIDE_RIGHT = 'invoices:override';
const EXTRA_RIGHTS: readonly string[] = [POS_OVERRIDE_RIGHT];

export const ALL_RIGHTS: readonly string[] = [
  ...AREAS.flatMap((a) => (VIEW_ONLY.has(a) ? [viewRight(a)] : [viewRight(a), manageRight(a)])),
  ...EXTRA_RIGHTS,
];
const ALL_RIGHTS_SET = new Set(ALL_RIGHTS);

export function isValidRight(value: unknown): value is string {
  return typeof value === 'string' && ALL_RIGHTS_SET.has(value);
}

export function normalizeRights(rights: readonly string[]): string[] {
  const out = new Set<string>();
  for (const r of rights) {
    if (!ALL_RIGHTS_SET.has(r)) continue;
    out.add(r);
    if (r.endsWith(':manage')) out.add(r.replace(':manage', ':view'));
  }
  return [...out].sort();
}

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
export function rightForRequest(area: Area, method: string): string {
  return SAFE_METHODS.has(method) ? viewRight(area) : manageRight(area);
}

export function hasRight(
  role: ShopRole | undefined,
  permissions: readonly string[] | undefined,
  right: string,
): boolean {
  if (role === 'OWNER') return true;
  if (!permissions || permissions.length === 0) return false;
  if (permissions.includes(right)) return true;
  if (right.endsWith(':view')) {
    return permissions.includes(right.replace(':view', ':manage'));
  }
  return false;
}

export const ROLE_PRESETS: Record<Exclude<ShopRole, 'OWNER' | 'STAFF'>, string[]> = {
  MANAGER: normalizeRights([
    'dashboard:view',
    'products:manage',
    'orders:manage',
    'invoices:manage',
    POS_OVERRIDE_RIGHT,
    'quotations:manage',
    'challans:manage',
    'payments:manage',
    'parties:manage',
    'stock:manage',
    'vendors:manage',
    'marketing:manage',
    'shop:manage',
    'reports:view',
  ]),
  STOCKIST: normalizeRights([
    'dashboard:view',
    'stock:manage',
    'vendors:manage',
    'products:view',
    'orders:view',
    'reports:view',
  ]),
  CASHIER: normalizeRights([
    'dashboard:view',
    'invoices:manage',
    'payments:manage',
    'parties:view',
    'products:view',
    'orders:view',
    'reports:view',
  ]),
};

export function presetFor(role: ShopRole): string[] {
  if (role === 'OWNER') return normalizeRights(ALL_RIGHTS);
  if (role === 'STAFF') return [];
  return ROLE_PRESETS[role];
}

export function requireRight(right: string) {
  return function (req: Request, res: Response, next: NextFunction): void {
    if (hasRight(req.user?.shopRole, req.user?.shopPermissions, right)) {
      next();
      return;
    }
    res.status(403).json({
      error: 'Forbidden',
      code: 'INSUFFICIENT_PERMISSION',
      required: right,
    });
  };
}

export function requireArea(area: Area) {
  return function (req: Request, res: Response, next: NextFunction): void {
    const right = rightForRequest(area, req.method);
    if (hasRight(req.user?.shopRole, req.user?.shopPermissions, right)) {
      next();
      return;
    }
    res.status(403).json({
      error: 'Forbidden',
      code: 'INSUFFICIENT_PERMISSION',
      required: right,
    });
  };
}

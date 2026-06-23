import { Request, Response, NextFunction } from 'express';
import { ShopRole } from '@prisma/client';

/// ── Custom per-employee permissions ────────────────────────────────
///
/// The owner grants rights at the granularity of an *area* × an
/// *action*. Areas map 1:1 to the merchant route groups; actions are
/// `view` (read/GET) and `manage` (mutate). A right is the string
/// `"<area>:<action>"`, e.g. "invoices:manage".
///
/// Invariants enforced here (not in the data):
///   • OWNER bypasses every check (they hold the shop).
///   • `manage` implies `view` — you can act on what you can see.
///   • A request to an area you lack `view` for is denied outright
///     (visibility is a grant too, per the owner's choice).
///
/// `reports` is the one view-only area (there's nothing to mutate);
/// `payouts` and `team` are sensitive but still grantable.

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

/// Areas that have no meaningful write surface — only `:view` exists.
const VIEW_ONLY: ReadonlySet<Area> = new Set<Area>(['dashboard', 'reports']);

export function viewRight(area: Area): string {
  return `${area}:view`;
}
export function manageRight(area: Area): string {
  return `${area}:manage`;
}

/// Standalone privileged rights beyond the area × {view,manage} grid.
/// `invoices:override` authorises sensitive till actions (discounts, price
/// overrides, voids, returns) — held by Owner/Manager, NOT a plain Cashier; a
/// cashier without it needs a manager to authorise the single action.
export const POS_OVERRIDE_RIGHT = 'invoices:override';
const EXTRA_RIGHTS: readonly string[] = [POS_OVERRIDE_RIGHT];

/// Every grantable right, for validation of incoming permission sets.
export const ALL_RIGHTS: readonly string[] = [
  ...AREAS.flatMap((a) => (VIEW_ONLY.has(a) ? [viewRight(a)] : [viewRight(a), manageRight(a)])),
  ...EXTRA_RIGHTS,
];
const ALL_RIGHTS_SET = new Set(ALL_RIGHTS);

export function isValidRight(value: unknown): value is string {
  return typeof value === 'string' && ALL_RIGHTS_SET.has(value);
}

/// Normalise a grant set: drop unknown rights, and ensure `manage`
/// always carries its `view` (so a stored set is self-consistent).
export function normalizeRights(rights: readonly string[]): string[] {
  const out = new Set<string>();
  for (const r of rights) {
    if (!ALL_RIGHTS_SET.has(r)) continue;
    out.add(r);
    if (r.endsWith(':manage')) out.add(r.replace(':manage', ':view'));
  }
  return [...out].sort();
}

/// The right a request needs, derived from the HTTP method: safe verbs
/// need only `view`, everything else needs `manage`.
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
export function rightForRequest(area: Area, method: string): string {
  return SAFE_METHODS.has(method) ? viewRight(area) : manageRight(area);
}

/// Does this membership satisfy `right`? OWNER bypasses; `manage`
/// satisfies the matching `view`.
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

/// Role presets — the toggle set a role pre-fills in the editor. OWNER
/// is intentionally absent (it's a bypass, never a stored set). These
/// mirror the scopes shown on the Team screen.
export const ROLE_PRESETS: Record<Exclude<ShopRole, 'OWNER' | 'STAFF'>, string[]> = {
  MANAGER: normalizeRights([
    'dashboard:view',
    'products:manage',
    'orders:manage',
    'invoices:manage',
    POS_OVERRIDE_RIGHT, // can authorise till discounts/voids/returns
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
    // View customers only — billing attaches a walk-in/customer server-side; a
    // cashier shouldn't edit/delete shop-wide party records (least privilege).
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

/// Express middleware: gate a single route on a specific named right
/// (beyond the route group's area), e.g. `invoices:override` on the
/// money-moving return-refund endpoint so it can't ride a plain
/// `orders:manage` grant. OWNER bypasses (via hasRight); fails closed.
/// Must run AFTER requireAuth + the area gate.
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

/// Express middleware: gate a merchant route group by `area`. Reads
/// require `<area>:view`, writes require `<area>:manage`. Must run AFTER
/// requireAuth (which attaches req.user.shopRole + shopPermissions).
/// Fails closed — a missing membership is denied.
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

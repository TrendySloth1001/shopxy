import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireArea } from '../../shared/http/permissions.js';
import { requireRole } from '../../shared/http/requireRole.js';
import { resolveShop } from '../../shared/http/resolveShop.js';
import { hsnController } from './hsn.controller.js';

/// The shared master is read-only over HTTP: it's seeded from the checked-in
/// manifest, so no request can move a merchant onto the wrong GST slab. The
/// only writes here are a shop's *own* data — its shortcut list and its
/// explicit rate overrides.
///
/// Literal paths are registered before anything that could shadow them.
const router = Router();

/// `/hsn` is mounted with plain `app.use`, outside `mountMerchant` — the reads
/// below are deliberately open (a tariff is public, and a shopless customer
/// token must still reach them). That exemption must not extend to the writes,
/// so the shop-scoped routes carry their own guards.
///
/// `requireArea` reads the *right* off the HTTP verb: GET needs `:view`,
/// anything else needs `:manage`. Overrides sit in `shop` rather than
/// `products` on purpose — an override restates this shop's tax position on a
/// code and applies to the whole catalogue and every future invoice, which is
/// a settings-level act, not a per-product edit. A Cashier holds
/// `products:view` and no `shop:*` at all, so they can read the master and
/// bill from it but cannot move a rate.
const merchantOnly = requireRole('OWNER');
const shortcutGuards = [merchantOnly, requireArea('products'), resolveShop];
const overrideGuards = [merchantOnly, requireArea('shop'), resolveShop];

// ── Shared reference data. Authenticated, not shop-scoped: a shopless caller
// (customer-app token) simply sees the platform tier.
router.get('/', asyncHandler(hsnController.search.bind(hsnController)));
router.get('/resolve', asyncHandler(hsnController.resolve.bind(hsnController)));
router.get('/tree', asyncHandler(hsnController.tree.bind(hsnController)));
router.get('/suggest', asyncHandler(hsnController.suggest.bind(hsnController)));

// ── The merchant's own shortcuts. Classification only, no rates — see
// ShopHsnShortcut. Guards are applied per-route rather than to the whole
// router so the reads above stay reachable without a shop.
router.get(
  '/shortcuts',
  ...shortcutGuards,
  asyncHandler(hsnController.listShortcuts.bind(hsnController)),
);
router.post(
  '/shortcuts',
  ...shortcutGuards,
  asyncHandler(hsnController.saveShortcut.bind(hsnController)),
);
router.delete(
  '/shortcuts/:id',
  ...shortcutGuards,
  asyncHandler(hsnController.deleteShortcut.bind(hsnController)),
);

// ── Explicit rate overrides. A tax position, so: separate endpoint, mandatory
// reason, recorded against the user who made it, and a stricter area.
router.get(
  '/overrides',
  ...overrideGuards,
  asyncHandler(hsnController.listOverrides.bind(hsnController)),
);
router.post(
  '/overrides',
  ...overrideGuards,
  asyncHandler(hsnController.createOverride.bind(hsnController)),
);
router.delete(
  '/overrides/:id',
  ...overrideGuards,
  asyncHandler(hsnController.deleteOverride.bind(hsnController)),
);

export default router;

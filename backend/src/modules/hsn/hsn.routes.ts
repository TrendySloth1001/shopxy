import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireArea } from '../../shared/http/permissions.js';
import { requirePlatformAdmin, requireRole } from '../../shared/http/requireRole.js';
import { resolveShop } from '../../shared/http/resolveShop.js';
import { hsnController } from './hsn.controller.js';

const router = Router();

const merchantOnly = requireRole('OWNER');
const shortcutGuards = [merchantOnly, requireArea('products'), resolveShop];
const overrideGuards = [merchantOnly, requireArea('shop'), resolveShop];

router.get('/', asyncHandler(hsnController.search.bind(hsnController)));
router.get('/resolve', asyncHandler(hsnController.resolve.bind(hsnController)));
router.get('/tree', asyncHandler(hsnController.tree.bind(hsnController)));
router.get('/suggest', asyncHandler(hsnController.suggest.bind(hsnController)));

router.get('/gaps', requirePlatformAdmin, asyncHandler(hsnController.gaps.bind(hsnController)));
router.post(
  '/gaps/resolve',
  requirePlatformAdmin,
  asyncHandler(hsnController.resolveGap.bind(hsnController)),
);

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

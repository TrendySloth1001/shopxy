import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requirePlatformAdmin } from '../../shared/http/requireRole.js';
import { categoriesController } from './categories.controller.js';

/// The taxonomy is **seeded from a checked-in manifest** (see
/// `catalog.seed.ts`). Merchants and customers can read it; only a
/// platform admin can mutate it out-of-band (rarely needed — usually
/// you edit the manifest and redeploy).
const router = Router();

// Read endpoints — both merchants and customers depend on these.
// The outer mount in app.ts wraps them in requireAuth so they're not
// fully public, but they're not role-gated either.
router.get('/', asyncHandler(categoriesController.list.bind(categoriesController)));
router.get('/tree', asyncHandler(categoriesController.tree.bind(categoriesController)));
router.get('/:id', asyncHandler(categoriesController.getById.bind(categoriesController)));

// Platform-admin-only writes. Kept around for the rare out-of-band
// fix; the canonical flow is "edit catalog.seed.ts and redeploy".
router.post('/', requirePlatformAdmin, asyncHandler(categoriesController.create.bind(categoriesController)));
router.patch('/:id', requirePlatformAdmin, asyncHandler(categoriesController.update.bind(categoriesController)));
router.delete('/:id', requirePlatformAdmin, asyncHandler(categoriesController.delete.bind(categoriesController)));

export default router;

import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { promotionsController } from './promotions.controller.js';

/// Merchant CRUD only. Mounted under /me/promotions behind
/// requireRole(OWNER) + resolveShop; the service scopes every read
/// and write through req.shopId so cross-shop probes are 404s.
const router = Router();
router.get('/', asyncHandler(promotionsController.list.bind(promotionsController)));
router.get(
  '/:id',
  asyncHandler(promotionsController.getOne.bind(promotionsController)),
);
router.post('/', asyncHandler(promotionsController.create.bind(promotionsController)));
router.patch(
  '/:id',
  asyncHandler(promotionsController.update.bind(promotionsController)),
);
router.delete(
  '/:id',
  asyncHandler(promotionsController.cancel.bind(promotionsController)),
);

export default router;

import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { analyticsController } from './analytics.controller.js';

/// Merchant analytics surface — mounted at /me/analytics behind
/// requireRole(OWNER) + resolveShop, so every query scopes through
/// req.shopId automatically. No public read; analytics is owner-only.
const router = Router();
router.get(
  '/products',
  asyncHandler(analyticsController.products.bind(analyticsController)),
);
router.get(
  '/flash-deals/:id',
  asyncHandler(analyticsController.flashDeal.bind(analyticsController)),
);

export default router;

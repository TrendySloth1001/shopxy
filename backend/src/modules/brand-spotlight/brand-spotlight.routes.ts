import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { brandSpotlightController } from './brand-spotlight.controller.js';

/// Public read: only APPROVED + currently-running spotlights. Mounted
/// before requireAuth so the customer home strip works pre-login.
export const brandSpotlightPublicRouter = Router();
brandSpotlightPublicRouter.get(
  '/active',
  asyncHandler(brandSpotlightController.listActive.bind(brandSpotlightController)),
);

/// Merchant — submit a request + see their own. Mounted under
/// /me/brand-spotlight with OWNER + resolveShop guards so shopId is
/// taken from req.shopId, not the body.
export const brandSpotlightMerchantRouter = Router();
brandSpotlightMerchantRouter.get(
  '/',
  asyncHandler(brandSpotlightController.listForShop.bind(brandSpotlightController)),
);
brandSpotlightMerchantRouter.post(
  '/request',
  asyncHandler(brandSpotlightController.submit.bind(brandSpotlightController)),
);
brandSpotlightMerchantRouter.delete(
  '/:id',
  asyncHandler(brandSpotlightController.cancel.bind(brandSpotlightController)),
);

/// Platform admin — full queue + approve / reject. Mounted under
/// /admin/brand-spotlight with requirePlatformAdmin.
export const brandSpotlightAdminRouter = Router();
brandSpotlightAdminRouter.get(
  '/',
  asyncHandler(brandSpotlightController.listAdmin.bind(brandSpotlightController)),
);
brandSpotlightAdminRouter.get(
  '/:id',
  asyncHandler(brandSpotlightController.getAdmin.bind(brandSpotlightController)),
);
brandSpotlightAdminRouter.patch(
  '/:id/approve',
  asyncHandler(brandSpotlightController.approve.bind(brandSpotlightController)),
);
brandSpotlightAdminRouter.patch(
  '/:id/reject',
  asyncHandler(brandSpotlightController.reject.bind(brandSpotlightController)),
);

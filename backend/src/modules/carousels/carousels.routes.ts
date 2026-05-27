import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { carouselsController } from './carousels.controller.js';

/// Merchant carousels — mounted at /me/carousels after requireAuth +
/// requireRole(OWNER) + resolveShop in app.ts. Every endpoint scopes by
/// req.shopId, so a merchant can never see or mutate another shop's
/// carousel by id-probing. Write endpoints sit behind carouselWriteLimiter.
export const carouselsMerchantRouter = Router();

carouselsMerchantRouter.get(
  '/',
  asyncHandler(carouselsController.listForShop.bind(carouselsController)),
);
carouselsMerchantRouter.get(
  '/:id',
  asyncHandler(carouselsController.getOneForShop.bind(carouselsController)),
);
carouselsMerchantRouter.post(
  '/',
  asyncHandler(carouselsController.createForShop.bind(carouselsController)),
);
carouselsMerchantRouter.patch(
  '/:id',
  asyncHandler(carouselsController.updateForShop.bind(carouselsController)),
);
carouselsMerchantRouter.delete(
  '/:id',
  asyncHandler(carouselsController.deleteForShop.bind(carouselsController)),
);

// Slides nested under a carousel — every handler resolves :carouselId
// to its owner shop before touching the slide row, so cross-shop probes
// land on a 404 same as direct carousel reads.
carouselsMerchantRouter.get(
  '/:carouselId/slides',
  asyncHandler(carouselsController.listSlides.bind(carouselsController)),
);
carouselsMerchantRouter.get(
  '/:carouselId/slides/:slideId',
  asyncHandler(carouselsController.getSlide.bind(carouselsController)),
);
carouselsMerchantRouter.post(
  '/:carouselId/slides',
  asyncHandler(carouselsController.createSlide.bind(carouselsController)),
);
carouselsMerchantRouter.patch(
  '/:carouselId/slides/:slideId',
  asyncHandler(carouselsController.updateSlide.bind(carouselsController)),
);
carouselsMerchantRouter.delete(
  '/:carouselId/slides/:slideId',
  asyncHandler(carouselsController.deleteSlide.bind(carouselsController)),
);

/// Admin — cross-shop listing under /admin/carousels with
/// requirePlatformAdmin. Reuses the merchant slide endpoints for slide
/// CRUD; the platform admin acts as if they own every shop's carousel.
/// shopId query param scopes the list (use `?shopId=null` for the
/// platform-curated bucket where shopId IS NULL).
export const carouselsAdminRouter = Router();

carouselsAdminRouter.get(
  '/',
  asyncHandler(carouselsController.listAdmin.bind(carouselsController)),
);

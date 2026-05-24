import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { bannersController } from './banners.controller.js';

/// Public read — mounted before requireAuth in app.ts. Anyone can fetch
/// active banners for a placement (the customer app calls this from the
/// home feed before login is required).
export const bannersPublicRouter = Router();
bannersPublicRouter.get(
  '/',
  asyncHandler(bannersController.listPublic.bind(bannersController)),
);
// Public slide-detail — banner + curated product list with computed
// sale prices. Used by the customer carousel tap target.
bannersPublicRouter.get(
  '/:id/slide',
  asyncHandler(bannersController.getPublicSlide.bind(bannersController)),
);

/// Admin CRUD — mounted under /admin/banners with requirePlatformAdmin
/// guard. List/get exposes full schedule + active state; create/update
/// validate CTA target + colors via zod schemas in the controller.
export const bannersAdminRouter = Router();
bannersAdminRouter.get(
  '/',
  asyncHandler(bannersController.listAdmin.bind(bannersController)),
);
bannersAdminRouter.get(
  '/:id',
  asyncHandler(bannersController.getOne.bind(bannersController)),
);
bannersAdminRouter.post(
  '/',
  asyncHandler(bannersController.create.bind(bannersController)),
);
bannersAdminRouter.patch(
  '/:id',
  asyncHandler(bannersController.update.bind(bannersController)),
);
bannersAdminRouter.delete(
  '/:id',
  asyncHandler(bannersController.delete.bind(bannersController)),
);

/// Merchant CRUD — mounted under /me/banners with requireAuth +
/// requireRole(OWNER) + resolveShop. Every endpoint is scoped to
/// req.shopId, so a merchant only ever sees / mutates their own
/// hero-carousel slides. Read goes straight to Postgres (no Redis cache)
/// because merchants edit infrequently and want their saves to land
/// without a 60s lag in the editor list.
export const bannersMerchantRouter = Router();
bannersMerchantRouter.get(
  '/',
  asyncHandler(bannersController.listForShop.bind(bannersController)),
);
bannersMerchantRouter.get(
  '/:id',
  asyncHandler(bannersController.getOneForShop.bind(bannersController)),
);
bannersMerchantRouter.post(
  '/',
  asyncHandler(bannersController.createForShop.bind(bannersController)),
);
bannersMerchantRouter.patch(
  '/:id',
  asyncHandler(bannersController.updateForShop.bind(bannersController)),
);
bannersMerchantRouter.delete(
  '/:id',
  asyncHandler(bannersController.deleteForShop.bind(bannersController)),
);

// Per-slide linked products. PUT replaces the whole list — simpler
// than per-row CRUD for a small N (max 60 products per slide).
bannersMerchantRouter.get(
  '/:id/products',
  asyncHandler(
    bannersController.listProductsForShopBanner.bind(bannersController),
  ),
);
bannersMerchantRouter.put(
  '/:id/products',
  asyncHandler(
    bannersController.replaceProductsForShopBanner.bind(bannersController),
  ),
);

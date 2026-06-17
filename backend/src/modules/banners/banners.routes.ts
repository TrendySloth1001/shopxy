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
// Public banner detail — the banner + its pinned products (with computed
// sale prices). The customer banner-detail page calls this.
bannersPublicRouter.get(
  '/:id',
  asyncHandler(bannersController.getPublicDetail.bind(bannersController)),
);

/// Admin CRUD — mounted under /admin/banners with requirePlatformAdmin.
/// Manages platform-wide banners (shopId = null) and can see/edit every
/// shop's banners. List/get expose full schedule + active state.
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
/// requireRole(OWNER) + resolveShop. A merchant uploads an image, picks
/// a placement + optional link + schedule, and owns the list. Every
/// query is scoped to the caller's shop.
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
// Pinned-product list (curated showcase + optional per-product discount).
bannersMerchantRouter.get(
  '/:id/products',
  asyncHandler(bannersController.listProductsForShopBanner.bind(bannersController)),
);
bannersMerchantRouter.put(
  '/:id/products',
  asyncHandler(bannersController.replaceProductsForShopBanner.bind(bannersController)),
);

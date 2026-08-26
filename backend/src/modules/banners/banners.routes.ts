import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { bannersController } from './banners.controller.js';

export const bannersPublicRouter = Router();
bannersPublicRouter.get(
  '/',
  asyncHandler(bannersController.listPublic.bind(bannersController)),
);
bannersPublicRouter.get(
  '/:id',
  asyncHandler(bannersController.getPublicDetail.bind(bannersController)),
);

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
bannersMerchantRouter.get(
  '/:id/products',
  asyncHandler(bannersController.listProductsForShopBanner.bind(bannersController)),
);
bannersMerchantRouter.put(
  '/:id/products',
  asyncHandler(bannersController.replaceProductsForShopBanner.bind(bannersController)),
);

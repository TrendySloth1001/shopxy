import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { marketplaceController } from './marketplace.controller.js';

const productRouter = Router();
productRouter.get('/:id', asyncHandler(marketplaceController.getProduct.bind(marketplaceController)));
productRouter.get(
  '/:id/frequently-bought-together',
  asyncHandler(marketplaceController.getFbt.bind(marketplaceController)),
);

const shopRouter = Router();
shopRouter.get('/:slug/products', asyncHandler(marketplaceController.listShopProducts.bind(marketplaceController)));

const categoryRouter = Router();
categoryRouter.get('/:slug/products', asyncHandler(marketplaceController.listCategoryProducts.bind(marketplaceController)));

export {
  productRouter as marketplaceProductRouter,
  shopRouter as marketplaceShopRouter,
  categoryRouter as marketplaceCategoryRouter,
};

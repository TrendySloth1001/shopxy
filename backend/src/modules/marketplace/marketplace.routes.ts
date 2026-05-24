import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { marketplaceController } from './marketplace.controller.js';

/// Public marketplace reads. Mounted BEFORE requireAuth at
/// /marketplace/products and /marketplace/shops in app.ts so anonymous
/// browsing works and we don't shadow the merchant-only /products
/// routes that live further down the mount chain.
///   GET /marketplace/products/:id        → public product detail
///   GET /marketplace/shops/:slug/products → paginated products inside a shop
const productRouter = Router();
productRouter.get('/:id', asyncHandler(marketplaceController.getProduct.bind(marketplaceController)));

const shopRouter = Router();
shopRouter.get('/:slug/products', asyncHandler(marketplaceController.listShopProducts.bind(marketplaceController)));

const categoryRouter = Router();
categoryRouter.get('/:slug/products', asyncHandler(marketplaceController.listCategoryProducts.bind(marketplaceController)));

export {
  productRouter as marketplaceProductRouter,
  shopRouter as marketplaceShopRouter,
  categoryRouter as marketplaceCategoryRouter,
};

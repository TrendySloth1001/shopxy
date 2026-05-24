import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { flashSalesController } from './flash-sales.controller.js';

/// Merchant CRUD — mounted at /me/flash-deals after requireAuth +
/// requireRole(OWNER) + resolveShop. Service scopes every query by
/// req.shopId; the merchant can never see or mutate another shop's
/// sales by id-probing.
export const flashSalesMerchantRouter = Router();
flashSalesMerchantRouter.get(
  '/',
  asyncHandler(flashSalesController.list.bind(flashSalesController)),
);
flashSalesMerchantRouter.get(
  '/:id',
  asyncHandler(flashSalesController.getOne.bind(flashSalesController)),
);
flashSalesMerchantRouter.post(
  '/',
  asyncHandler(flashSalesController.create.bind(flashSalesController)),
);
flashSalesMerchantRouter.patch(
  '/:id',
  asyncHandler(flashSalesController.update.bind(flashSalesController)),
);
flashSalesMerchantRouter.delete(
  '/:id',
  asyncHandler(flashSalesController.cancel.bind(flashSalesController)),
);

/// Public list of currently-running sales — mounted before requireAuth
/// so unauthenticated browsing of the home feed surfaces flash deals.
export const flashSalesPublicRouter = Router();
flashSalesPublicRouter.get(
  '/active',
  asyncHandler(flashSalesController.listPublic.bind(flashSalesController)),
);

import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { purchaseRequestsController } from './purchase-requests.controller.js';

// Merchant-facing inbox + decision endpoints. Mounted at `/orders` in
// server.ts.
const merchantRouter = Router();

merchantRouter.get(
  '/',
  asyncHandler((req, res) => purchaseRequestsController.listForMerchant(req, res)),
);
merchantRouter.get(
  '/pending-count',
  asyncHandler((req, res) => purchaseRequestsController.pendingCount(req, res)),
);
merchantRouter.get(
  '/:id',
  asyncHandler((req, res) => purchaseRequestsController.getForMerchant(req, res)),
);
merchantRouter.post(
  '/:id/confirm',
  asyncHandler((req, res) => purchaseRequestsController.confirm(req, res)),
);
merchantRouter.post(
  '/:id/reject',
  asyncHandler((req, res) => purchaseRequestsController.reject(req, res)),
);

// Customer-facing endpoints. Mounted at `/me/orders` in server.ts.
const customerRouter = Router();
customerRouter.post(
  '/',
  asyncHandler((req, res) => purchaseRequestsController.createForCustomer(req, res)),
);
customerRouter.get(
  '/',
  asyncHandler((req, res) => purchaseRequestsController.listForCustomer(req, res)),
);
customerRouter.get(
  '/:id',
  asyncHandler((req, res) => purchaseRequestsController.getForCustomer(req, res)),
);
customerRouter.post(
  '/:id/cancel',
  asyncHandler((req, res) => purchaseRequestsController.cancelForCustomer(req, res)),
);

export { merchantRouter as ordersRouter, customerRouter as customerOrdersRouter };

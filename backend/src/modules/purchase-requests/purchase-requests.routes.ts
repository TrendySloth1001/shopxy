import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { purchaseRequestsController } from './purchase-requests.controller.js';

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
merchantRouter.post(
  '/:id/events',
  asyncHandler((req, res) => purchaseRequestsController.addShippingEvent(req, res)),
);

const customerRouter = Router({ mergeParams: true });
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
  '/:id/shops/:childId/cancel',
  asyncHandler((req, res) => purchaseRequestsController.cancelChildForCustomer(req, res)),
);
customerRouter.post(
  '/:id/reorder',
  asyncHandler((req, res) => purchaseRequestsController.reorderForCustomer(req, res)),
);
customerRouter.post(
  '/:id/pay',
  asyncHandler((req, res) => purchaseRequestsController.payForOrder(req, res)),
);
customerRouter.post(
  '/:id/payment/sync',
  asyncHandler((req, res) => purchaseRequestsController.syncPayment(req, res)),
);
customerRouter.get(
  '/:id/shops/:childId/invoice.pdf',
  asyncHandler((req, res) => purchaseRequestsController.downloadCustomerInvoicePdf(req, res)),
);

export { merchantRouter as ordersRouter, customerRouter as customerOrdersRouter };

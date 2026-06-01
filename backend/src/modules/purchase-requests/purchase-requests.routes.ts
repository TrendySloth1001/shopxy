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
// Merchant-side shipping milestones (PACKED / SHIPPED / OUT_FOR_DELIVERY /
// DELIVERED / RETURNED) — drives the customer-facing tracking timeline.
merchantRouter.post(
  '/:id/events',
  asyncHandler((req, res) => purchaseRequestsController.addShippingEvent(req, res)),
);

// Customer-facing endpoints. Mounted at `/me/orders` in server.ts.
// mergeParams lets nested routes read `:id` from the parent mount,
// and lets sub-paths declare their own params (`:childId`) cleanly.
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
// Per-shop child cancel. The customer Flutter app posts to
// `/me/orders/:id/shops/:childId/cancel`. The controller reads both
// params from the merged route definition.
customerRouter.post(
  '/:id/shops/:childId/cancel',
  asyncHandler((req, res) => purchaseRequestsController.cancelChildForCustomer(req, res)),
);
// Re-add cart-ready items from a past order.
customerRouter.post(
  '/:id/reorder',
  asyncHandler((req, res) => purchaseRequestsController.reorderForCustomer(req, res)),
);
// Start an online gateway payment for this order's payable remainder.
customerRouter.post(
  '/:id/pay',
  asyncHandler((req, res) => purchaseRequestsController.payForOrder(req, res)),
);
// Client-confirm after the checkout sheet returns success — settles if the live
// provider order is paid (webhook backstop) and returns the paymentStatus.
customerRouter.post(
  '/:id/payment/sync',
  asyncHandler((req, res) => purchaseRequestsController.syncPayment(req, res)),
);
// Per-shop invoice PDF download. Path matches the customer-app data
// source exactly (note the `invoice.pdf` literal, not a `/pdf` segment).
customerRouter.get(
  '/:id/shops/:childId/invoice.pdf',
  asyncHandler((req, res) => purchaseRequestsController.downloadCustomerInvoicePdf(req, res)),
);

export { merchantRouter as ordersRouter, customerRouter as customerOrdersRouter };

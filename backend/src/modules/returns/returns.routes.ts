import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';
import { returnsController } from './returns.controller.js';

// Customer-side. Mounted at `/me/returns` + a parent-scoped submit at
// `/me/orders/:parentId/returns` so the URL reflects the relationship.
const customerReturnsRouter = Router();
customerReturnsRouter.get(
  '/',
  asyncHandler((req, res) => returnsController.list(req, res)),
);
customerReturnsRouter.get(
  '/:id',
  asyncHandler((req, res) => returnsController.getOwn(req, res)),
);
customerReturnsRouter.post(
  '/:id/cancel',
  asyncHandler((req, res) => returnsController.cancel(req, res)),
);

// Customer submit lives under the parent order so the relationship is
// captured by the URL — the request body still carries the childId
// since one parent can span multiple shops.
const customerOrderReturnsSubmitRouter = Router({ mergeParams: true });
customerOrderReturnsSubmitRouter.post(
  '/',
  asyncHandler((req, res) => returnsController.submit(req, res)),
);

// Merchant inbox + workflow. Mounted at `/orders/returns`.
const merchantReturnsRouter = Router();
merchantReturnsRouter.get(
  '/',
  asyncHandler((req, res) => returnsController.listMerchant(req, res)),
);
merchantReturnsRouter.get(
  '/:id',
  asyncHandler((req, res) => returnsController.getMerchant(req, res)),
);
merchantReturnsRouter.post(
  '/:id/approve',
  asyncHandler((req, res) => returnsController.approve(req, res)),
);
merchantReturnsRouter.post(
  '/:id/reject',
  asyncHandler((req, res) => returnsController.reject(req, res)),
);
merchantReturnsRouter.post(
  '/:id/picked-up',
  asyncHandler((req, res) => returnsController.pickedUp(req, res)),
);
merchantReturnsRouter.post(
  '/:id/received',
  asyncHandler((req, res) => returnsController.received(req, res)),
);
// Issuing the refund moves real money (wallet credit + Route claw-back),
// so it's gated on the sensitive `invoices:override` right in addition to
// the `orders:manage` the rest of the returns workflow needs — a plain
// order-manager can advance the workflow but not release funds. Owner and
// Manager hold the override; a custom `orders:manage`-only grant does not.
merchantReturnsRouter.post(
  '/:id/refund',
  requireRight(POS_OVERRIDE_RIGHT),
  asyncHandler((req, res) => returnsController.refund(req, res)),
);

export {
  customerReturnsRouter,
  customerOrderReturnsSubmitRouter,
  merchantReturnsRouter,
};

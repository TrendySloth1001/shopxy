import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requireRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';
import { returnsController } from './returns.controller.js';

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

const customerOrderReturnsSubmitRouter = Router({ mergeParams: true });
customerOrderReturnsSubmitRouter.post(
  '/',
  asyncHandler((req, res) => returnsController.submit(req, res)),
);

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

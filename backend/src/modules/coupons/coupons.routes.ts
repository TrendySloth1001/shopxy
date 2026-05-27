import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { couponsController } from './coupons.controller.js';

const customerCouponsRouter = Router();
customerCouponsRouter.get(
  '/',
  asyncHandler((req, res) => couponsController.listAvailable(req, res)),
);
customerCouponsRouter.post(
  '/validate',
  asyncHandler((req, res) => couponsController.validate(req, res)),
);
customerCouponsRouter.post(
  '/auto-apply',
  asyncHandler((req, res) => couponsController.autoApply(req, res)),
);

/// Merchant-scoped admin surface. Mounted under `/me/coupons-admin` so
/// the customer-facing `/me/coupons` path stays clean (the customer
/// app calls it on every checkout to load redeemable codes).
const merchantCouponsRouter = Router();
merchantCouponsRouter.get(
  '/',
  asyncHandler((req, res) => couponsController.listMerchant(req, res)),
);
merchantCouponsRouter.post(
  '/',
  asyncHandler((req, res) => couponsController.createMerchant(req, res)),
);
merchantCouponsRouter.patch(
  '/:id',
  asyncHandler((req, res) => couponsController.updateMerchant(req, res)),
);
merchantCouponsRouter.delete(
  '/:id',
  asyncHandler((req, res) => couponsController.deactivateMerchant(req, res)),
);

export { customerCouponsRouter, merchantCouponsRouter };

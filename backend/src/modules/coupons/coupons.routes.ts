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

const merchantCouponsRouter = Router();
merchantCouponsRouter.get(
  '/',
  asyncHandler((req, res) => couponsController.listMerchant(req, res)),
);
merchantCouponsRouter.get(
  '/:id/redemptions',
  asyncHandler((req, res) => couponsController.redemptionsMerchant(req, res)),
);
merchantCouponsRouter.get(
  '/:id',
  asyncHandler((req, res) => couponsController.getMerchant(req, res)),
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

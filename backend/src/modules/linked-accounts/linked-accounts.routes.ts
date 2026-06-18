import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { linkedAccountsController } from './linked-accounts.controller.js';

// Merchant-facing Route onboarding. Mounted at `/linked-account` behind
// ownerOnly + resolveShop in app.ts, so req.shopId is the caller's own shop.
const linkedAccountsRouter = Router();

linkedAccountsRouter.post(
  '/',
  asyncHandler((req, res) => linkedAccountsController.start(req, res)),
);
// Connect an existing Razorpay linked account by id (skip the KYC wizard).
linkedAccountsRouter.post(
  '/connect',
  asyncHandler((req, res) => linkedAccountsController.connectVerify(req, res)),
);
linkedAccountsRouter.post(
  '/connect/confirm',
  asyncHandler((req, res) => linkedAccountsController.connectConfirm(req, res)),
);
linkedAccountsRouter.get(
  '/',
  asyncHandler((req, res) => linkedAccountsController.status(req, res)),
);

export default linkedAccountsRouter;

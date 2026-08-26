import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { walletController } from './wallet.controller.js';

const customerWalletRouter = Router();
customerWalletRouter.get(
  '/',
  asyncHandler((req, res) => walletController.snapshot(req, res)),
);

export { customerWalletRouter };

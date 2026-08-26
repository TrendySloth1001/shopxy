import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { shopController } from './shop.controller.js';

const router = Router();

router.get('/', asyncHandler(shopController.getMine.bind(shopController)));
router.put('/', asyncHandler(shopController.updateMine.bind(shopController)));
router.post('/publish', asyncHandler(shopController.setPublished.bind(shopController)));

export default router;

export const shopOnboardingRouter = Router();
shopOnboardingRouter.post(
  '/shop',
  asyncHandler(shopController.createMine.bind(shopController)),
);

export const adminShopRouter = Router();
adminShopRouter.get(
  '/',
  asyncHandler(shopController.listAdmin.bind(shopController)),
);
adminShopRouter.post(
  '/:id/verified',
  asyncHandler(shopController.setVerified.bind(shopController)),
);

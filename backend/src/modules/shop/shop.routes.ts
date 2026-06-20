import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { shopController } from './shop.controller.js';

/// Merchant-scoped shop routes — mounted at /me/shop AFTER requireAuth
/// and ownerOnly guards in server.ts. Each handler reads req.user.sub
/// to resolve the caller's shop; no shop id ever appears in the URL.
const router = Router();

router.get('/', asyncHandler(shopController.getMine.bind(shopController)));
router.put('/', asyncHandler(shopController.updateMine.bind(shopController)));
router.post('/publish', asyncHandler(shopController.setPublished.bind(shopController)));

export default router;

/// First-shop onboarding — mounted at /me/onboarding behind requireAuth +
/// ownerOnly ONLY (no requireArea): a freshly-registered OWNER has no
/// ShopMember yet, so an area gate would 403 them out of creating their
/// first shop. See app.ts.
export const shopOnboardingRouter = Router();
shopOnboardingRouter.post(
  '/shop',
  asyncHandler(shopController.createMine.bind(shopController)),
);

/// Platform-admin verified toggle. Mounted at /admin/shops/:id with
/// `requirePlatformAdmin` upstream. Self-serve verification is not
/// allowed — only platform admins can flip this flag.
export const adminShopRouter = Router();
adminShopRouter.get(
  '/',
  asyncHandler(shopController.listAdmin.bind(shopController)),
);
adminShopRouter.post(
  '/:id/verified',
  asyncHandler(shopController.setVerified.bind(shopController)),
);

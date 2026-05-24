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

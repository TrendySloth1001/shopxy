import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { shopController } from './shop.controller.js';

/// Public marketplace routes — mounted BEFORE requireAuth in server.ts.
/// Returns only published shops; unpublished shops 404 to prevent
/// metadata leakage during the merchant's setup phase.
const router = Router();

router.get('/:slug', asyncHandler(shopController.getPublicBySlug.bind(shopController)));

export default router;

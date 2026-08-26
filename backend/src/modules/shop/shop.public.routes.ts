import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { shopController } from './shop.controller.js';

const router = Router();

router.get('/:slug', asyncHandler(shopController.getPublicBySlug.bind(shopController)));

export default router;

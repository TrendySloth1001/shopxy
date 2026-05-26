import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { cartController } from './cart.controller.js';

const router = Router();

router.get('/', asyncHandler((req, res) => cartController.list(req, res)));
router.put(
  '/:productId',
  asyncHandler((req, res) => cartController.setQuantity(req, res)),
);
router.delete(
  '/:productId',
  asyncHandler((req, res) => cartController.remove(req, res)),
);
router.delete('/', asyncHandler((req, res) => cartController.clear(req, res)));
router.post('/merge', asyncHandler((req, res) => cartController.merge(req, res)));

export default router;

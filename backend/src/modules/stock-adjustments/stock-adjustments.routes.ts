import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { stockAdjustmentsController } from './stock-adjustments.controller.js';

const router = Router();

router.post('/', asyncHandler(stockAdjustmentsController.create.bind(stockAdjustmentsController)));
router.get('/', asyncHandler(stockAdjustmentsController.list.bind(stockAdjustmentsController)));
router.get('/:id', asyncHandler(stockAdjustmentsController.getById.bind(stockAdjustmentsController)));
router.post('/:id/reverse', asyncHandler(stockAdjustmentsController.reverse.bind(stockAdjustmentsController)));

export default router;

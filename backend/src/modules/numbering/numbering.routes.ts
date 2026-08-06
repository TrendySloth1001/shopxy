import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { numberingController } from './numbering.controller.js';

const router = Router();

router.get('/', asyncHandler(numberingController.list.bind(numberingController)));
router.patch('/:series', asyncHandler(numberingController.upsert.bind(numberingController)));
router.post(
  '/:series/next-number',
  asyncHandler(numberingController.setNextNumber.bind(numberingController)),
);

export default router;

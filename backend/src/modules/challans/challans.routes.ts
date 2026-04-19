import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import {
  createChallan,
  listChallans,
  getChallan,
  cancelChallan,
  convertToInvoice,
} from './challans.controller.js';

const router = Router();

router.post('/', asyncHandler(createChallan));
router.get('/', asyncHandler(listChallans));
router.get('/:id', asyncHandler(getChallan));
router.patch('/:id/cancel', asyncHandler(cancelChallan));
router.post('/:id/convert', asyncHandler(convertToInvoice));

export default router;

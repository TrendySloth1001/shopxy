import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import {
  createChallan,
  listChallans,
  getChallan,
  cancelChallan,
  convertToInvoice,
  downloadChallanPdf,
  archiveChallan,
  unarchiveChallan,
} from './challans.controller.js';

const router = Router();

router.post('/', asyncHandler(createChallan));
router.get('/', asyncHandler(listChallans));
router.get('/:id', asyncHandler(getChallan));
router.get('/:id/pdf', asyncHandler(downloadChallanPdf));
router.patch('/:id/cancel', asyncHandler(cancelChallan));
router.post('/:id/convert', asyncHandler(convertToInvoice));
router.post('/:id/archive', asyncHandler(archiveChallan));
router.post('/:id/unarchive', asyncHandler(unarchiveChallan));

export default router;

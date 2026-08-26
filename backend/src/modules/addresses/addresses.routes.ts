import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { addressesController } from './addresses.controller.js';

const router = Router();
router.get('/', asyncHandler(addressesController.list.bind(addressesController)));
router.post('/', asyncHandler(addressesController.create.bind(addressesController)));
router.patch('/:id', asyncHandler(addressesController.update.bind(addressesController)));
router.post('/:id/default', asyncHandler(addressesController.setDefault.bind(addressesController)));
router.delete('/:id', asyncHandler(addressesController.delete.bind(addressesController)));

export default router;

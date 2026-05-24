import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { addressesController } from './addresses.controller.js';

/// Customer-owned delivery addresses. Mounted at `/me/addresses` in
/// app.ts under requireAuth so the user can only read/write their
/// own rows (service-level filter on `userId = req.user.sub`).
const router = Router();
router.get('/', asyncHandler(addressesController.list.bind(addressesController)));
router.post('/', asyncHandler(addressesController.create.bind(addressesController)));
router.patch('/:id', asyncHandler(addressesController.update.bind(addressesController)));
router.post('/:id/default', asyncHandler(addressesController.setDefault.bind(addressesController)));
router.delete('/:id', asyncHandler(addressesController.delete.bind(addressesController)));

export default router;

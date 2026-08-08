import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { quotationsController } from './quotations.controller.js';

/// Merchant-side quotation routes (mounted ownerOnly). Customers act on
/// quotations via the read+accept/decline routes under /me/parties/:id.
const router = Router();

router.post('/', asyncHandler((req, res) => quotationsController.create(req, res)));
router.get('/', asyncHandler((req, res) => quotationsController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => quotationsController.getById(req, res)));
router.get('/:id/pdf', asyncHandler((req, res) => quotationsController.downloadPdf(req, res)));
router.post('/:id/cancel', asyncHandler((req, res) => quotationsController.cancel(req, res)));
router.post('/:id/archive', asyncHandler((req, res) => quotationsController.archive(req, res)));
router.post('/:id/unarchive', asyncHandler((req, res) => quotationsController.unarchive(req, res)));
router.post('/:id/respond', asyncHandler((req, res) => quotationsController.respond(req, res)));
router.post('/:id/decline-request', asyncHandler((req, res) => quotationsController.declineRequest(req, res)));

export default router;

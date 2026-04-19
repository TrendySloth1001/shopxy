import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { invoicesController } from './invoices.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => invoicesController.create(req, res)));
router.get('/', asyncHandler((req, res) => invoicesController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => invoicesController.getById(req, res)));
router.get('/:id/pdf', asyncHandler((req, res) => invoicesController.downloadPdf(req, res)));
router.patch('/:id/status', asyncHandler((req, res) => invoicesController.updateStatus(req, res)));
router.delete('/:id', asyncHandler((req, res) => invoicesController.delete(req, res)));

export default router;

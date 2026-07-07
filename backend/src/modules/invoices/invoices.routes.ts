import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { invoicesController } from './invoices.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => invoicesController.create(req, res)));
router.get('/', asyncHandler((req, res) => invoicesController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => invoicesController.getById(req, res)));
router.get('/:id/pdf', asyncHandler((req, res) => invoicesController.downloadPdf(req, res)));
// Order matters: /:id/status must come before /:id so Express doesn't
// try to match the literal "status" segment against the generic update.
router.patch('/:id/status', asyncHandler((req, res) => invoicesController.updateStatus(req, res)));
router.patch('/:id', asyncHandler((req, res) => invoicesController.update(req, res)));
router.post('/:id/convert', asyncHandler((req, res) => invoicesController.convert(req, res)));
router.post('/:id/notes', asyncHandler((req, res) => invoicesController.issueNote(req, res)));
router.delete('/:id', asyncHandler((req, res) => invoicesController.delete(req, res)));

export default router;

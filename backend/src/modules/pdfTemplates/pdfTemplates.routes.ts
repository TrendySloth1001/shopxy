import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { pdfTemplatesController } from './pdfTemplates.controller.js';

const router = Router();

router.get('/', asyncHandler(pdfTemplatesController.list.bind(pdfTemplatesController)));
router.get('/:id/sample', asyncHandler(pdfTemplatesController.sample.bind(pdfTemplatesController)));

export default router;

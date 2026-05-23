import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { customFieldsController } from './customFields.controller.js';

const router = Router();

// ── Tree (sections + fields in one round-trip) ─────────────────────
router.get('/tree', asyncHandler(customFieldsController.getTree.bind(customFieldsController)));

// ── Templates ──────────────────────────────────────────────────────
router.get('/templates', asyncHandler(customFieldsController.listTemplates.bind(customFieldsController)));
router.post('/templates/apply', asyncHandler(customFieldsController.applyTemplate.bind(customFieldsController)));

// ── Sections ───────────────────────────────────────────────────────
router.get('/sections', asyncHandler(customFieldsController.listSections.bind(customFieldsController)));
router.post('/sections', asyncHandler(customFieldsController.createSection.bind(customFieldsController)));
router.patch('/sections/reorder', asyncHandler(customFieldsController.reorderSections.bind(customFieldsController)));
router.patch('/sections/:id', asyncHandler(customFieldsController.updateSection.bind(customFieldsController)));
router.delete('/sections/:id', asyncHandler(customFieldsController.deleteSection.bind(customFieldsController)));

// ── Shop-wide field definitions ────────────────────────────────────
router.get('/', asyncHandler(customFieldsController.listDefinitions.bind(customFieldsController)));
router.post('/', asyncHandler(customFieldsController.createDefinition.bind(customFieldsController)));
router.patch('/reorder', asyncHandler(customFieldsController.reorderDefinitions.bind(customFieldsController)));
router.patch('/:id', asyncHandler(customFieldsController.updateDefinition.bind(customFieldsController)));
router.delete('/:id', asyncHandler(customFieldsController.deleteDefinition.bind(customFieldsController)));

// Note: per-product value routes live under /products/:id/custom-fields,
// registered separately in server.ts so the URL hierarchy matches the
// resource ownership ("a product has values; the shop has definitions").
export default router;

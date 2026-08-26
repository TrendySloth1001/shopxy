import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { customFieldsController } from './customFields.controller.js';

const router = Router();

router.get('/tree', asyncHandler(customFieldsController.getTree.bind(customFieldsController)));

router.get('/templates', asyncHandler(customFieldsController.listTemplates.bind(customFieldsController)));
router.post('/templates/apply', asyncHandler(customFieldsController.applyTemplate.bind(customFieldsController)));

router.get('/sections', asyncHandler(customFieldsController.listSections.bind(customFieldsController)));
router.post('/sections', asyncHandler(customFieldsController.createSection.bind(customFieldsController)));
router.patch('/sections/reorder', asyncHandler(customFieldsController.reorderSections.bind(customFieldsController)));
router.patch('/sections/:id', asyncHandler(customFieldsController.updateSection.bind(customFieldsController)));
router.delete('/sections/:id', asyncHandler(customFieldsController.deleteSection.bind(customFieldsController)));

router.get('/', asyncHandler(customFieldsController.listDefinitions.bind(customFieldsController)));
router.post('/', asyncHandler(customFieldsController.createDefinition.bind(customFieldsController)));
router.patch('/reorder', asyncHandler(customFieldsController.reorderDefinitions.bind(customFieldsController)));
router.patch('/:id', asyncHandler(customFieldsController.updateDefinition.bind(customFieldsController)));
router.delete('/:id', asyncHandler(customFieldsController.deleteDefinition.bind(customFieldsController)));

export default router;

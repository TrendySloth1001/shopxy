import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { requirePlatformAdmin } from '../../shared/http/requireRole.js';
import { categoriesController } from './categories.controller.js';

const router = Router();

router.get('/', asyncHandler(categoriesController.list.bind(categoriesController)));
router.get('/tree', asyncHandler(categoriesController.tree.bind(categoriesController)));
router.get('/:id', asyncHandler(categoriesController.getById.bind(categoriesController)));

router.post('/', requirePlatformAdmin, asyncHandler(categoriesController.create.bind(categoriesController)));
router.patch('/:id', requirePlatformAdmin, asyncHandler(categoriesController.update.bind(categoriesController)));
router.delete('/:id', requirePlatformAdmin, asyncHandler(categoriesController.delete.bind(categoriesController)));

export default router;

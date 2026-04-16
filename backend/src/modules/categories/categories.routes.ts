import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { categoriesController } from './categories.controller.js';

const router = Router();

router.post('/', asyncHandler(categoriesController.create.bind(categoriesController)));
router.get('/', asyncHandler(categoriesController.list.bind(categoriesController)));
router.get('/:id', asyncHandler(categoriesController.getById.bind(categoriesController)));
router.patch('/:id', asyncHandler(categoriesController.update.bind(categoriesController)));
router.delete('/:id', asyncHandler(categoriesController.delete.bind(categoriesController)));

export default router;

import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { usersController } from './users.controller.js';

const router = Router();

router.post('/', asyncHandler(usersController.create.bind(usersController)));
router.get('/', asyncHandler(usersController.list.bind(usersController)));
router.get('/:id', asyncHandler(usersController.getById.bind(usersController)));
router.patch('/:id', asyncHandler(usersController.update.bind(usersController)));
router.delete('/:id', asyncHandler(usersController.delete.bind(usersController)));

export default router;

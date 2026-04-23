import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { partiesController } from './parties.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => partiesController.create(req, res)));
router.get('/', asyncHandler((req, res) => partiesController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => partiesController.getById(req, res)));
router.patch('/:id', asyncHandler((req, res) => partiesController.update(req, res)));
router.delete('/:id', asyncHandler((req, res) => partiesController.delete(req, res)));

export default router;

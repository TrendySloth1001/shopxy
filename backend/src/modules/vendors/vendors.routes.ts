import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { vendorsController } from './vendors.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => vendorsController.create(req, res)));
router.get('/', asyncHandler((req, res) => vendorsController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => vendorsController.getById(req, res)));
router.patch('/:id', asyncHandler((req, res) => vendorsController.update(req, res)));
router.delete('/:id', asyncHandler((req, res) => vendorsController.delete(req, res)));

export default router;

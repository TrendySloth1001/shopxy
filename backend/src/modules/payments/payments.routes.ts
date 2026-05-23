import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { paymentsController } from './payments.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => paymentsController.create(req, res)));
router.get('/', asyncHandler((req, res) => paymentsController.list(req, res)));
router.get('/:id', asyncHandler((req, res) => paymentsController.getById(req, res)));
router.delete('/:id', asyncHandler((req, res) => paymentsController.delete(req, res)));

export default router;

import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { dashboardController } from './dashboard.controller.js';

const router = Router();

router.get('/stats', asyncHandler(dashboardController.stats.bind(dashboardController)));
router.get('/receivables', asyncHandler(dashboardController.receivables.bind(dashboardController)));
router.get('/payables', asyncHandler(dashboardController.payables.bind(dashboardController)));

export default router;

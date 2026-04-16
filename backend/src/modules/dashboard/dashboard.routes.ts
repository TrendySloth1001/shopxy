import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { dashboardController } from './dashboard.controller.js';

const router = Router();

router.get('/stats', asyncHandler(dashboardController.stats.bind(dashboardController)));

export default router;

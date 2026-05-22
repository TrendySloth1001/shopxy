import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { reportsController } from './reports.controller.js';

const router = Router();

router.get('/sales', asyncHandler((req, res) => reportsController.sales(req, res)));
router.get('/purchases', asyncHandler((req, res) => reportsController.purchases(req, res)));
router.get('/gst', asyncHandler((req, res) => reportsController.gst(req, res)));
router.get('/pnl', asyncHandler((req, res) => reportsController.pnl(req, res)));

export default router;

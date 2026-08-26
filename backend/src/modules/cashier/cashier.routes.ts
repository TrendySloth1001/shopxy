import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { cashierController } from './cashier.controller.js';

export const cashierMerchantRouter = Router();

cashierMerchantRouter.get('/current', asyncHandler((req, res) => cashierController.current(req, res)));
cashierMerchantRouter.get('/report', asyncHandler((req, res) => cashierController.report(req, res)));
cashierMerchantRouter.post('/shift/open', asyncHandler((req, res) => cashierController.open(req, res)));
cashierMerchantRouter.post('/shift/close', asyncHandler((req, res) => cashierController.close(req, res)));
cashierMerchantRouter.post('/cash-movement', asyncHandler((req, res) => cashierController.movement(req, res)));
cashierMerchantRouter.get('/shifts', asyncHandler((req, res) => cashierController.shifts(req, res)));
cashierMerchantRouter.get('/shifts/:id/report', asyncHandler((req, res) => cashierController.shiftReport(req, res)));
cashierMerchantRouter.get('/returnable/:invoiceId', asyncHandler((req, res) => cashierController.returnable(req, res)));
cashierMerchantRouter.post('/return', asyncHandler((req, res) => cashierController.processReturn(req, res)));
cashierMerchantRouter.post('/authorize', asyncHandler((req, res) => cashierController.authorize(req, res)));

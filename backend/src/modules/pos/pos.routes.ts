import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { posController } from './pos.controller.js';

export const posMerchantRouter = Router();

posMerchantRouter.post('/ticket', asyncHandler((req, res) => posController.ticket(req, res)));

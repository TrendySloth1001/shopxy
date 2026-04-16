import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { stockController } from './stock.controller.js';

const router = Router();

router.post('/', asyncHandler(stockController.createTransaction.bind(stockController)));
router.get('/', asyncHandler(stockController.listTransactions.bind(stockController)));

export default router;

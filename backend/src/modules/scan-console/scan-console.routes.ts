import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { scanConsoleController } from './scan-console.controller.js';

export const scanConsoleMerchantRouter = Router();

scanConsoleMerchantRouter.post(
  '/ticket',
  asyncHandler(scanConsoleController.ticket.bind(scanConsoleController)),
);

scanConsoleMerchantRouter.post(
  '/scan',
  asyncHandler(scanConsoleController.scan.bind(scanConsoleController)),
);

scanConsoleMerchantRouter.post(
  '/clear',
  asyncHandler(scanConsoleController.clear.bind(scanConsoleController)),
);

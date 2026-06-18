import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { scanConsoleController } from './scan-console.controller.js';

/// Merchant scan-console routes — mounted under /me/scan-console with
/// requireAuth + requireRole(OWNER) + area gate + resolveShop. The phone is a
/// pure REST publisher here (POST /scan); the live receive side is the
/// WebSocket at /ws/scan-console (see scan-console.service.ts), authed by a
/// ticket minted at POST /ticket.
export const scanConsoleMerchantRouter = Router();

// Mint a single-use WebSocket ticket for the web console.
scanConsoleMerchantRouter.post(
  '/ticket',
  asyncHandler(scanConsoleController.ticket.bind(scanConsoleController)),
);

// Phone publishes a scanned code; resolved product fans out to live consoles.
scanConsoleMerchantRouter.post(
  '/scan',
  asyncHandler(scanConsoleController.scan.bind(scanConsoleController)),
);

// Reset every live console for this shop.
scanConsoleMerchantRouter.post(
  '/clear',
  asyncHandler(scanConsoleController.clear.bind(scanConsoleController)),
);

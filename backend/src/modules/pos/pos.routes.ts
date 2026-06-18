import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { posController } from './pos.controller.js';

/// POS routes — the cart + checkout run entirely over the WebSocket (pos.ws.ts).
/// The only REST endpoint is the WS ticket mint, gated under the 'invoices' area
/// (requireAuth + ownerOnly + requireArea + resolveShop in app.ts).
export const posMerchantRouter = Router();

posMerchantRouter.post('/ticket', asyncHandler((req, res) => posController.ticket(req, res)));

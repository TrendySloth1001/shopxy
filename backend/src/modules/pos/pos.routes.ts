import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { posController } from './pos.controller.js';

/// POS routes — mounted under /me/pos with requireAuth + ownerOnly +
/// requireArea('invoices') + resolveShop. Reads need invoices:view, writes need
/// invoices:manage (the money path). The cart is server-authoritative; each
/// mutation returns the fresh sale snapshot.
export const posMerchantRouter = Router();

posMerchantRouter.post('/ticket', asyncHandler(posController.ticket.bind(posController)));
posMerchantRouter.post('/sales', asyncHandler(posController.openSale.bind(posController)));
posMerchantRouter.get('/sales', asyncHandler(posController.listOpenSales.bind(posController)));
posMerchantRouter.get('/sales/:id', asyncHandler(posController.getSale.bind(posController)));
posMerchantRouter.patch('/sales/:id', asyncHandler(posController.patchSale.bind(posController)));
posMerchantRouter.post('/sales/:id/scan', asyncHandler(posController.scan.bind(posController)));
posMerchantRouter.post('/sales/:id/quick-add', asyncHandler(posController.quickAdd.bind(posController)));
posMerchantRouter.post('/sales/:id/items', asyncHandler(posController.addItem.bind(posController)));
posMerchantRouter.patch('/sales/:id/items/:productId', asyncHandler(posController.patchItem.bind(posController)));
posMerchantRouter.delete('/sales/:id/items/:productId', asyncHandler(posController.removeItem.bind(posController)));
posMerchantRouter.post('/sales/:id/void', asyncHandler(posController.voidSale.bind(posController)));
posMerchantRouter.post('/sales/:id/checkout', asyncHandler(posController.checkout.bind(posController)));

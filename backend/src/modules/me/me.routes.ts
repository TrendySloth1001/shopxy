import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { meController } from './me.controller.js';

const router = Router();

router.get('/links', asyncHandler((req, res) => meController.links(req, res)));
router.get(
  '/linked-shops',
  asyncHandler((req, res) => meController.linkedShops(req, res)),
);
router.get(
  '/catalog/products',
  asyncHandler((req, res) => meController.catalog(req, res)),
);
router.get(
  '/catalog/products/:productId',
  asyncHandler((req, res) => meController.catalogProduct(req, res)),
);
router.get(
  '/catalog/categories',
  asyncHandler((req, res) => meController.catalogCategories(req, res)),
);
router.get(
  '/parties/:partyId/invoices',
  asyncHandler((req, res) => meController.partyInvoices(req, res)),
);
router.get(
  '/parties/:partyId/invoices/:invoiceId',
  asyncHandler((req, res) => meController.partyInvoice(req, res)),
);
router.get(
  '/vendors/:vendorId/invoices',
  asyncHandler((req, res) => meController.vendorInvoices(req, res)),
);
router.get(
  '/vendors/:vendorId/invoices/:invoiceId',
  asyncHandler((req, res) => meController.vendorInvoice(req, res)),
);

router.get(
  '/wishlist',
  asyncHandler((req, res) => meController.wishlist(req, res)),
);
router.post(
  '/wishlist/:productId',
  asyncHandler((req, res) => meController.wishlistAdd(req, res)),
);
router.delete(
  '/wishlist/:productId',
  asyncHandler((req, res) => meController.wishlistRemove(req, res)),
);

export default router;

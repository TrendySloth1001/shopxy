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
  '/parties/:partyId/caution',
  asyncHandler((req, res) => meController.partyCaution(req, res)),
);
router.post(
  '/parties/:partyId/caution-requests',
  asyncHandler((req, res) => meController.createCautionRequest(req, res)),
);
router.get(
  '/parties/:partyId/caution-requests',
  asyncHandler((req, res) => meController.cautionRequests(req, res)),
);
router.post(
  '/parties/:partyId/caution-requests/:reqId/cancel',
  asyncHandler((req, res) => meController.cancelCautionRequest(req, res)),
);
router.get(
  '/parties/:partyId/quotations',
  asyncHandler((req, res) => meController.quotations(req, res)),
);
router.post(
  '/parties/:partyId/quotations',
  asyncHandler((req, res) => meController.requestQuotation(req, res)),
);
router.post(
  '/parties/:partyId/quotations/:quotationId/cancel',
  asyncHandler((req, res) => meController.cancelQuotation(req, res)),
);
router.get(
  '/parties/:partyId/quotations/:quotationId/pdf',
  asyncHandler((req, res) => meController.quotationPdf(req, res)),
);
router.get(
  '/parties/:partyId/quotations/:quotationId',
  asyncHandler((req, res) => meController.quotation(req, res)),
);
router.post(
  '/parties/:partyId/quotations/:quotationId/accept',
  asyncHandler((req, res) => meController.acceptQuotation(req, res)),
);
router.post(
  '/parties/:partyId/quotations/:quotationId/decline',
  asyncHandler((req, res) => meController.declineQuotation(req, res)),
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

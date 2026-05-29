import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { cautionController } from './caution.controller.js';

/// Shop-wide caution-request inbox for the merchant. Approve/reject live on
/// the party-scoped routes (`/parties/:id/caution-requests/:reqId/...`) — the
/// inbox rows carry their partyId, so the merchant app routes actions there.
const router = Router();

router.get('/', asyncHandler((req, res) => cautionController.listShopRequests(req, res)));

export default router;

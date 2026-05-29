import { Router } from 'express';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { partiesController } from './parties.controller.js';
import { cautionController } from '../caution/caution.controller.js';

const router = Router();

router.post('/', asyncHandler((req, res) => partiesController.create(req, res)));
router.get('/', asyncHandler((req, res) => partiesController.list(req, res)));
router.get('/:id/overview', asyncHandler((req, res) => partiesController.overview(req, res)));
router.get('/:id/ledger', asyncHandler((req, res) => partiesController.ledger(req, res)));
router.get('/:id/changes', asyncHandler((req, res) => partiesController.changes(req, res)));
// Caution / security deposits held against the party.
router.get('/:id/caution', asyncHandler((req, res) => cautionController.history(req, res)));
router.post('/:id/caution/deposit', asyncHandler((req, res) => cautionController.deposit(req, res)));
router.post('/:id/caution/refund', asyncHandler((req, res) => cautionController.refund(req, res)));
router.post('/:id/caution/adjust', asyncHandler((req, res) => cautionController.adjust(req, res)));
router.post('/:id/caution/forfeit', asyncHandler((req, res) => cautionController.forfeit(req, res)));
// Party-initiated caution requests (merchant reviews them).
router.get('/:id/caution-requests', asyncHandler((req, res) => cautionController.listPartyRequests(req, res)));
router.post('/:id/caution-requests/:reqId/approve', asyncHandler((req, res) => cautionController.approveRequest(req, res)));
router.post('/:id/caution-requests/:reqId/reject', asyncHandler((req, res) => cautionController.rejectRequest(req, res)));
router.get('/:id', asyncHandler((req, res) => partiesController.getById(req, res)));
router.patch('/:id', asyncHandler((req, res) => partiesController.update(req, res)));
router.delete('/:id', asyncHandler((req, res) => partiesController.delete(req, res)));

export default router;
